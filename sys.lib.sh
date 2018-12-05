#!/bin/sh

# Sys: dealing with vars, functions, env.

sys_lib_load()
{
  test -n "$LOG" || return 102
  test -n "$uname" || uname="$(uname -s)"
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
}

# Sh var-based increment
incr() # VAR [AMOUNT=1]
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
  test -n "$1" || return

  set -- "$1" "$(which "$1")" || return

  test -n "$2" -a -x "$2"
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
  $LOG debug "sys" "try-exec-func '$1'"
  func_exists $1 || return $?
  local func=$1
  shift 1
  $func "$@" || return $?
}

# TODO: redesign
try_var()
{
  local value="$(eval echo "\$$1")"
  test -n "$value" || return 1
  echo $value
}

# Get echo-local output, and return 1 on empty value. See echo-local spec.
try_value()
{
  local value=
  test $# -gt 1 && {
    value="$(eval echo "\"\$$(echo_local "$@")\"")"
  } || {
    value="$(echo $(eval echo "\$$1"))"
  }
  test -n "$value" || return 1
  echo "$value"
}

# setup-tmp [(RAM_)TMPDIR]
setup_tmpd()
{
  test -n "$1" || set -- "$base-$(get_uuid)" "$2"
  test -n "$2" -o -z "$RAM_TMPDIR" || set -- "$1" "$RAM_TMPDIR"
  test -n "$2" -o -z "$TMPDIR" || set -- "$1" "$TMPDIR"
  test -n "$2" || {
        $LOG warn sys "No RAM tmpdir/No tmpdir settings found"
        test -w "/dev/shm" && RAM_TMPDIR=/dev/shm/tmp
      }
  test -d $2/$1 || mkdir -p $2/$1
  test -n "$2" -a -d "$2" || $LOG error sys "Not a dir: '$2'" 1
  echo "$2/$1"
}

# Echo path to new file in temp. dir. with ${base}- as filename prefix,
# .out suffix and subcmd with uuid as middle part.
# setup-tmp [ext [uuid [(RAM_)TMPDIR]]]
setup_tmpf() # [Ext [UUID [TMPDIR]]]
{
  test -n "$1" || set -- .out "$2" "$3"
  test -n "$2" || set -- $1 $(get_uuid) "$3"
  test -n "$1" -a -n "$2" || $LOG error sys "empty arg(s)" 1
  test -z "$4" || $LOG error sys "surplus arg(s) '$3'" 1

  test -n "$3" || set -- "$1" "$2" "$(setup_tmpd)"
  test -n "$3" -a -d "$3" || $LOG error sys "Not a dir: '$3'" 1

  test -n "$(dirname $3/$2$1)" -a "$(dirname $3/$2$1)" \
    || mkdir -p "$(dirname $3/$2$1)"
  echo $3/$2$1
}

# sys-prompt PROMPT [VAR=choice_confirm]
sys_prompt()
{
  test -n "$1" || $LOG error sys "sys-prompt: arg expected" 1
  test -n "$2" || set -- "$1" choice_confirm
  test -z "$3" || $LOG error sys "surplus-args '$3'" 1
  echo $1
  read -n 1 $2
}

# sys-confirm PROMPT
sys_confirm()
{
  local choice_confirm=
  sys_prompt "$1" choice_confirm
  trueish "$choice_confirm"
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
      test -f "$input" || $LOG error sys "Input file '$input' expected" 1
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

  $LOG note sys "Capture: $1 $2 $3"
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

  $LOG note sys "Captured: $_out_var_: $tmp"

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
      $LOG debug sys "Execline: $execnr. '$execline'"
      $execline || return 3
    done
  test ! -e "$execs" || { execnr=$(count_lines "$execs"); rm "$execs"; }
  $LOG info sys "Exec-arg: executed $execnr lines"
  test $execnr -gt 0 || return 1
}
