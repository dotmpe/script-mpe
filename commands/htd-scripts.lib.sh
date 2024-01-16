#!/bin/sh


# XXX:
#htd_scripts_lib__load()
#{
#  test "${package_lib_load:-}"
#}


htd_scripts_names()
{
  test -e "$PACK_JSON" ||
      error "Pack-Json-Main '$PACK_JSON' missing" 1
  jsotk.py keys -O lines $PACK_JSON scripts | sort -u | {
    test -n "${1-}" && {
      while read name;do fnmatch "$1" "$name" || continue;echo "$name";done
    } || { cat - ; }
  }
}

htd_scripts_list()
{
  test -n "$package_id" || error "No package env loaded" 1
  htd_scripts_names "$@" | while read name
  do
    printf -- "$name\n"
    verbose_no_exec=1 htd_scripts_exec $name
  done
}

# Determine wether package script exists even without having it loaded. Takes
# a few milisec more than using env.
htd_scripts_id_exist_grep () # Name-ID
{
  local vid; upper=0 mkvid "$1" ; set -- scripts_${vid} "${2-}"
  test -n "$2" || set -- "$1" "$PACK_SH"
  grep -q '^\<\(package_'"${1}"'\|package_'"${1}"'__0\)\>=' "$2"
}

# Determine wether package script exists while pacakge.sh is loaded into env
htd_scripts_id_exist_env ()
{
  local vid; upper=0 mkvid "$1" ; set -- scripts_${vid}
  package_sh_list_exists "$1" || package_sh_key_exists "$1"
}

# Execute script with given ID
htd_scripts_exec () # Script-Id
{
  # Execute env and script-lines in subshell
  (
    SCRIPTPATH='' ln=0
    unset Build_Deps_Default_Paths

    test -z "$package_cwd" || {
      note "Moving to '$package_cwd'"
      cd $package_cwd
    }

    # Initialize shell from profile script
    . "$PACK_ENVD/${package_env_name:-"main"}.sh" || return

    # Write scriptline with expanded vars
    std_info "Expanded '$(eval echo \"$@\")'"
    set -- $(eval echo \"$*\")
    run_scriptname="$1"
    shift

    std_info "Starting '$run_scriptname' ($PWD) '$*'"
    package_js_script "$run_scriptname" | while read -r scriptline
    do
      export ln=$(( $ln + 1 ))

      # Header or verbose output
      not_trueish "${verbose_no_exec-}" && {
        std_info "Scriptline: '$scriptline'"
      } || {
        printf -- "\t$scriptline\n"
        continue
      }

      # Execute
      eval $scriptline && continue || { r=$?
          echo "$run_scriptname:$ln: '$scriptline'" >> $failed
          error "At line $ln '$scriptline' for '$run_scriptname' '$*' ($r)" $r
        }
      # NOTE: execute scriptline with args only once
      set --
    done
    trueish "${verbose_no_exec-}" || note "'$run_scriptname' completed"
  )
}

htd_scripts_exec_compiled()
{
  export compiled_script="$PWD/$PACK_SCRIPTS/$1.sh" ; shift;
  (
    SCRIPTPATH=''
    unset Build_Deps_Default_Paths

    test -z "$package_cwd" || {
      note "Moving to '$package_cwd'"
      cd $package_cwd
    }
    . $PWD/$package_env_file && . $compiled_script
  )
}

htd_scripts_run () # Name-ID
{
  # Execute compiled variant if not turned off
  { test -e "$PACK_SCRIPTS/$1.sh" && not_falseish "$use_cache"
  } && {

    std_info "Using cached script"
    htd_scripts_exec_compiled "$@"
    return $?
  }

  # Test wether script exists
  htd_scripts_id_exist_grep "$1" || error "No script '$1'" 1

  # Create/update shell profile script
  package_sh_env_script &&

  # Defer to execute routine
  htd_scripts_exec "$@"
}
