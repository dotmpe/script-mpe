#!/bin/sh

# Sys: dealing with vars, functions, env.

sys_lib_load()
{
  export _14MB=14680064
  export _6MB=7397376
  export _5k=5120

  #test -n "$MIN_SIZE" || MIN_SIZE=1
  test -n "$MIN_SIZE" || MIN_SIZE=$_6MB

  test -n "$uname" || uname="$(uname -s)"
  test -n "$os" || os="$(uname -s | tr 'A-Z' 'a-z')"
  test -n "$username" || username="$(whoami | tr -dc 'A-Za-z0-9_-')"
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  test -n "$arch" || arch="$(uname -p)"
  test -n "$mach" || mach="$(uname -m)"

  test -n "$SCR_SYS_SH" ||  {
    test -n "$SHELL" &&
        SCR_SYS_SH="$(basename "$SHELL")" ||
        SCR_SYS_SH=bash
  }

  test -n "$TMPDIR" && {
    test -z "$RAM_TMPDIR" && {
      require_fs_casematch $TMPDIR
    } || {
      test -d "$RAM_TMPDIR" || error "Not a dir $RAM_TMPDIR" 1
      require_fs_casematch "$RAM_TMPDIR"
    }
  } || {
    test -d /tmp || error "No /tmp" 1
    TMPDIR=/tmp
    $LOG info "$scriptname" "TMPDIR=$TMPDIR (should be in shell profile)" >&2
  }
}


require_fs_casematch()
{
  local CWD="$(pwd)"
  test -n "$1" && {
    cd "$1"
  }
  test -e ".fs-casematch" || {
    test -e ".fs-nocasematch" && {
      $LOG warn "$scriptname" "Case-insensitive fs '$1' detected!" >&2
    } || {

      echo 'ok' > abc
      echo 'notok' > ABC
      test "$(echo $( cat abc ABC))" = "ok notok" && {
        $LOG debug "$scriptname" "Case-sensitive fs '$1' OK" >&2
        rm abc ABC || true
        touch .fs-casematch
      } || {
        test "$(echo $( cat abc ABC))" = "notok notok" && {
          rm abc || true
          $LOG warn "$scriptname" "Case-insensitive fs '$1' detected!" >&2
          touch .fs-nocasematch
        } || {
          rm abc ABC || true
          cd "$CWD"
          $LOG error "$scriptname" "Unknown error" 1 >&2
        }
      }
    }
  }
  cd "$CWD"
}

# Sh var-based increment
incr()
{
  local incr_amount
  test -n "$2" && incr_amount=$2 || incr_amount=1
  v=$(eval echo \$$1)
  eval $1=$(( $v + $incr_amount ))
}

getidx()
{
  test -n "$1" || error getidx-array 1
  test -n "$2" || error getidx-index 1
  test -z "$3" || error getidx-surplus 1
  local idx=$2
  set -- $1
  eval echo \$$idx
}

# test for var decl, io. to no override empty
var_isset()
{
    test "$1" = "base" && return 1
  test -n "$1" || error "var-isset arg expected" 1
  # [2017-02-03] somehow Sh compatible setup broke so (testing at least) so
  #   split it up into bash, and expanded on testing. And some more testing and
  #   fiddling. Using SCR_SYS_SH=bash-sh to make some frontend exceptions.
  case "$SCR_SYS_SH" in

    bash-sh|sh|zsh )
        # Aside from declare or typeset in newer reincarnations,
        # in posix or modern Bourne mode this seems to work best:
        ( set | grep -q '\<'"$1"'=' ) || return 1
      ;;

    bash )
        # Bash: https://www.cyberciti.biz/faq/linux-unix-howto-check-if-bash-variable-defined-not/
        [[ ! ${!1} && ${!1-unset} ]] && return 1 || return 0
        #$HOME/bin/tools/sh/var-isset.bash "$1"
      ;;

    * )
        error "SCR_SYS_SH='$SCR_SYS_SH'" 12
      ;;

  esac
}

# require vars to be initialized, regardless of value
req_vars()
{
  while test $# -gt 0
  do
    var_isset "$1" || return 1
    shift
  done
}

# Error unless non-empty and true-ish value
trueish() # Str
{
  test -n "$1" || return 1
  case "$1" in [Oo]n|[Tt]rue|[Yyj]|[Yy]es|1) return 0;;
    * ) return 1;;
  esac
}

# No error on empty, or not trueish match
not_trueish()
{
  test -n "$1" || return 0
  trueish "$1" && return 1 || return 0
}

# Error unless non-empty and falseish
falseish()
{
  test -n "$1" || return 1
  case "$1" in
    [Oo]ff|[Ff]alse|[Nn]|[Nn]o|0)
      return 0;;
    * )
      return 1;;
  esac
}

# No error on empty, or not-falseish match
not_falseish() # Str
{
  test -n "$1" || return 0
  falseish "$1" && return 1 || return 0
}

cmd_exists()
{
  test -x $(which $1) || return $?
}

func_exists()
{
  type $1 2> /dev/null 1> /dev/null || return $?
  # XXX bash/bsd-darwin: test "$(type -t $1)" = "function" && return
  return 0
}

try_exec_func()
{
  test -n "$1" || return 97
  debug "try-exec-func '$1'"
  func_exists $1 || return $?
  local func=$1
  shift 1
  $func "$@" || return $?
}

try_var()
{
  local value="$(eval echo "\$$1")"
  test -n "$value" || return 1
  echo $value
}

# echo value of varname $1 on stdout if non empty
test_out()
{
  test -n "$1" || error test_out 1
  local val="$(echo $(eval echo "\$$1"))"
  test -z "$val" || eval echo "\\$val"
}

create_ram_disk()
{
  test -n "$1" || error "Name expected" 1
  test -n "$2" || error "Size expected" 1
  test -z "$3" || error "Surplus arguments '$3'" 1

  case "$uname" in

    Darwin )
        local size=$(( $2 * 2048 ))
        diskutil erasevolume 'Case-sensitive HFS+' \
          "$1" `hdiutil attach -nomount ram://$size`
      ;;

      # Linux
      # mount -t tmpfs -o size=512m tmpfs /mnt/ramdisk

    * )
        error "Unsupported platform '$uname'" 1
      ;;

  esac
}

# setup-tmp [(RAM_)TMPDIR]
setup_tmpd()
{
  test -n "$1" || set -- "$base-$(get_uuid)" "$2"
  test -n "$2" -o -z "$RAM_TMPDIR" || set -- "$1" "$RAM_TMPDIR"
  test -n "$2" -o -z "$TMPDIR" || set -- "$1" "$TMPDIR"
  test -n "$2" || {
        warn "No RAM tmpdir/No tmpdir settings found"
        test -w "/dev/shm" && RAM_TMPDIR=/dev/shm/tmp
      }
  test -d $2/$1 || mkdir -p $2/$1
  test -n "$2" -a -d "$2" || error "Not a dir: '$2'" 1
  echo "$2/$1"
}

# Echo path to new file in temp. dir. with ${base}- as filename prefix,
# .out suffix and subcmd with uuid as middle part.
# setup-tmp [ext [uuid [(RAM_)TMPDIR]]]
setup_tmpf() # [Ext [UUID [TMPDIR]]]
{
  test -n "$1" || set -- .out "$2" "$3"
  test -n "$2" || set -- $1 $(get_uuid) "$3"
  test -n "$1" -a -n "$2" || error "empty arg(s)" 1
  test -z "$4" || error "surplus arg(s) '$3'" 1

  test -n "$3" || set -- "$1" "$2" "$(setup_tmpd)"
  test -n "$3" -a -d "$3" || error "Not a dir: '$3'" 1

  test -n "$(dirname $3/$2$1)" -a "$(dirname $3/$2$1)" \
    || mkdir -p "$(dirname $3/$2$1)"
  echo $3/$2$1
}

# sys-prompt PROMPT [VAR=choice_confirm]
sys_prompt()
{
  test -n "$1" || error "sys-prompt: arg expected" 1
  test -n "$2" || set -- "$1" choice_confirm
  test -z "$3" || error "surplus-args '$3'" 1
  echo $1
  read $2
}

# sys-confirm PROMPT
sys_confirm()
{
  local choice_confirm=
  sys_prompt "$1" choice_confirm
  trueish "$choice_confirm"
}

# If any of VALUES it not in variable LIST, add it
assert_list() # LIST VALUES...
{
	local to_add= list=$1 items="$(eval echo "\$$1")"
	shift 1
	to_add="$( for value in $@;
		do
			fnmatch "* $value *" " $items " && continue;
			echo $value;
		done )"
	eval $list="$(echo $items $to_add)"
}

# If ITEM is in items of LIST, add VALUES not already in list
expand_item() # LIST ITEM VALUES...
{
	local to_add= list=$1 item=$2 items="$(eval echo "\$$1")"
	shift 2
	fnmatch "* $item *" " $items " && {
		assert_list $list "$@"
	} || true
}

pretty_print_var()
{
  var_isset kvsep || kvsep='='
  pretty_var="$(printf -- "$1" | tr -s '_' '-')"
  falseish "$2" && {
    printf "!$pretty_var\n"
  } || {
    trueish "$2" && {
      printf "$pretty_var\n"
    } || {
      value="$(printf -- "$2" | sed 's/\ /\\ /g')"
      printf "$pretty_var$kvsep$value\n"
    }
  }
}

print_var()
{
  case "$2" in
    *'"'*|*" "*|*"'"* )
      printf -- '%s\n' "$1=\"$2\"" ;;
    * )
      printf -- '%s\n' "$1=$2" ;;
  esac
}

# Add an entry to PATH, see add-env-path-lookup for solution to other env vars
add_env_path() # Prepend-Value Append-Value
{
  test -e "$1" -o -e "$2" || {
    echo "No such file or directory '$*'" >&2
    return 1
  }
  test -n "$1" && {
    case "$PATH" in
      $1:* | *:$1 | *:$1:* ) ;;
      * ) eval PATH=$1:$PATH ;;
    esac
  } || {
    test -n "$2" && {
      case "$PATH" in
        $2:* | *:$2 | *:$2:* ) ;;
        * ) eval PATH=$PATH:$2 ;;
      esac
    }
  }
  # XXX: to export or not to launchctl
  #test "$uname" != "Darwin" || {
  #  launchctl setenv "$1" "$(eval echo "\$$1")" ||
  #    echo "Darwin setenv '$1' failed ($?)" >&2
  #}
}

# Add an entry to colon-separated paths, ie. PATH, CLASSPATH alike lookup paths
add_env_path_lookup() # Var-Name Prepend-Value Append-Value
{
  local val="$(eval echo "\$$1")"
  test -e "$2" -o -e "$3" || {
    echo "No such file or directory '$*'" >&2
    return 1
  }
  test -n "$2" && {
    case "$val" in
      $2:* | *:$2 | *:$2:* ) ;;
      * ) test -n "$val" && eval $1=$2:$val || eval $1=$2;;
    esac
  } || {
    test -n "$3" && {
      case "$val" in
        $3:* | *:$3 | *:$3:* ) ;;
        * ) test -n "$val" && eval $1=$val:$3 || eval $1=$3;;
      esac
    }
  }
}

# List individual entries/paths in lookup path env-var (ie. PATH or CLASSPATH)
lookup_path_list() # VAR-NAME
{
  test -n "$1" || error "lookup-path varname expected" 1
  eval echo \"\$$1\" | tr ':' '\n'
}

# lookup-path List existing local paths, or fail if second arg is not listed
# lookup-test: command to test equality with, default test_exists
# lookup-first: boolean setting to stop after first success
lookup_path() # VAR-NAME LOCAL-PATH
{
  test -n "$lookup_test" || lookup_test="test_exists"
  lookup_path_list $1 | while read _PATH
  do
    eval $lookup_test \""$_PATH"\" \""$2"\" && {
      trueish "$lookup_first" && return 0 || continue
    } || continue
  done
}

# Test if local path/name is overruled. Lists paths for hidden LOCAL instances.
lookup_path_shadows() # VAR-NAME LOCAL
{
  local r=
  tmpf=$(setup_tmpf .lookup-shadows)
  lookup_first=false lookup_path "$@" >$tmpf
  lines=$( count_lines $tmpf )
  test "$lines" = "0" && { r=2
    } || { r=0
      test "$lines" = "1" || { r=1
          cat $tmpf
          #tail +2 "$tmpf"
      }
    }
  rm $tmpf
  return $r
}

# Return 1 if env was provided, or 0 if default was set
default_env() # VAR-NAME DEFAULT-VALUE
{
  test -n "$1" -a $# -eq 2 || error "default-env requires two args ($*)" 1
  local vid= sid= id=
  trueish "$title" && upper= || {
    test -n "$upper" || upper=1
  }
  mkvid "$1"
  mksid "$1"
  unset upper
  test -n "$(eval echo \$$vid)" || {
    debug "No $sid env ($vid), using '$2'"
    eval $vid="$2"
    return 0
  }
  return 1
}


get_kv_k() # Key-Value-Str
{
  echo "$1" | cut -d'=' -f1
}

get_kv_v() # Key-Value-Str [Env-Prefix [Key-Str]]
{
  test -n "$3" || set -- "$1" "$2" "$(get_kv_k "$1")"
  fnmatch "*=*" "$1" && {
    eval echo \"$(expr_substr "$1" "$(( 2 + ${#3} ))" "$(( ${#1} - ${#3}  ))")\"
  } || {
    eval echo \"\$$2$3\"
  }
}


# Source profile if it exists, or create one using given default and current env
# The result should be whatever is defined in an existing profile, the current env and whatever
# defaults where provided. If the file exists, the processing costs should be minimal, and mostly
# determined by the profile file.
# This means the env var validation is left to the profile script, and the profile script is only
# written if a value for every var is provided. No other schema validation.
req_profile() # Name Vars...
{
  test -n "$SCR_ETC" -a -w "$SCR_ETC" || error "Scr-Etc '$SCR_ETC'" 1
  local name=$1 ; shift

  test -e "$SCR_ETC/${name}.sh" && {
    # NOTE: only simply scalars, no quoting, whitespace etc.
    eval $* ||
        error "Error evaluating defaults '$*'" 1
    . "$SCR_ETC/${name}.sh" ||
        error "Error sourcing '${name}' profile" 1
  } || {
    {
      while test $# -gt 0
      do
          fnmatch *"="* "$1" && {
            var=$(echo "$1" | cut -f 1 -d '=')
            value=$(echo "$1" | sed 's/^[^=]*=//g')
          } || {
            var=$1
            value="$(eval echo \"\$$var\")"
          }
          test -n "$value" || stderr error "Missing '$var' value" 1
          printf -- "$var=\"$value\"\n"
          shift
      done
    } > "$SCR_ETC/${name}-temp.sh"
    mv "$SCR_ETC/${name}-temp.sh" "$SCR_ETC/$name.sh"
  }
}

rnd_passwd()
{
  test -n "$1" || set -- 11
  cat /dev/urandom | LC_ALL=ascii tr -cd 'a-z0-9' | head -c $1
}

min()
{
  p= s= act=echo foreach_do "$@" | sort -r | tail -n 1
}

max()
{
  p= s= act=echo foreach_do "$@" | sort | tail -n 1
}

# Capture cmd/func output in file, return status. Set out_file to provide path.
# The fourth argument signals to pass current stdin or the given file to the
# subshell pipeline.
capture() # CMD [RET-VAR=ret_var] [OUT-FILE-VAR=out_file] [-|FILE]
{
  local exec_name="$1" _ret_var_="$2" _out_var_="$3" input="$4"
  shift 4 # Regard rest as func/cmd-args
  test -n "$_ret_var_" || _ret_var_=ret_var
  test -n "$_out_var_" || _out_var_=out_file

  stdout="$(eval echo \"\$$_out_var_\")"
  test -n "$stdout" || stdout=$(setup_tmpf .capture-stdout)

  local return_status=
  test -n "$input" && {
    test "$input" != "-" && {
      test -f "$input" || error "Input file '$input' expected" 1
    } || {
      input=$(setup_tmpf .capture-input)
      cat >"$input"
    }

    return_status="$(cat "$input" | $exec_name "$@" >"$stdout" ; echo $?)"
  } || {
    return_status="$($exec_name "$@" >"$stdout" ; echo $?)"
  }

  eval $_ret_var_=$return_status
  eval $_out_var_="$stdout"
}

# Capture cmd/func output in var, status
# env: pref= set_always=
# don't use names cmd_name, _ret_var_ or _out_var_; those would overlap with
# local vars
capture_var() # CMD [RET-VAR=ret_var] [OUT-VAR=out_var] [ARGS...]
{
  test -n "$2" || set -- "$1" "ret_var" "$3"
  local cmd_name="$1" _ret_var_="$2" _out_var_="$3"

  note "Capture: $1 $2 $3"
  shift 3
  test -n "$_out_var_" || {
    fnmatch "* *" "$cmd_name" && _out_var_=out_var || _out_var_=$cmd_name
  }

  # Execute, store return value at path and capture stdout in tmp var.
  local failed=$(setup_tmpf .capture-failed)

  test -n "$pref" && {
      local tmp="$(${pref} $cmd_name || echo $?>$failed)"
    } || {
      local tmp="$($cmd_name "$@" || echo $?>$failed)"
    }

  note "Captured: $_out_var_: $tmp"

  # Set return var and cleanup
  test -e "$failed" && {
      eval $_ret_var_=$(head -n1 "$failed")
      trueish "$set_always" && {
          eval $_out_var_="$tmp"
      } || true
      rm "$failed"
    } || {
      eval $_ret_var_=0
      eval $_out_var_="$tmp"
    }
}

# Turn '--' seperated argument seq. into lines
exec_arg_lines()
{
  local exec=
  while test $# -gt 0
  do
    test "$1" = "--" && { echo "$exec"; exec=; shift; continue; }
    test -n "$exec" && exec="$exec $1" || exec="$1"
    shift
  done
  test -z "$exec" || echo "$exec"
}

# Execute arguments, or return on first failure, empty args, or no cmdlines
exec_arg() # CMDLINE [ -- CMDLINE ]...
{
  test -n "$*" || return 2
  local execs=$(setup_tmpf .execs) execnr=0
  exec_arg_lines "$@" | while read -r execline
    do
      test -n "$execline" || continue
      echo "$execline">>"$execs"
      execnr=$(count_lines "$execs")
      debug "Execline: $execnr. '$execline'"
      $execline || return 3
    done
  test ! -e "$execs" || { execnr=$(count_lines "$execs"); rm "$execs"; }
  info "Exec-arg: executed $execnr lines"
  test $execnr -gt 0 || return 1
}
