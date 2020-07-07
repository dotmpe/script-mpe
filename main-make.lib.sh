#!/usr/bin/env bash
#!/bin/sh
# Main-Make: build shell scripts from subcommands without boilerplate
# Created: 2020-06-30

main_make_lib_load()
{
  type main_define >/dev/null 2>&1 ||
      . $CWD/main-defs.lib.sh

  type mkvid >/dev/null 2>&1 ||
      . $HOME/.conf/script/str-uc.lib.sh

  { type trueish >/dev/null 2>&1 &&
      type type_exists >/ev/null 2>&1
  } ||
      . $HOME/.conf/script/util-min-uc.lib.sh
      #. $CWD/tools/sh/parts/func_exists.lib.sh
      #. $CWD/tools/sh/parts/trueish.lib.sh
}

make_read_herescript()
{
  local _ header
  make_scriptbody=
  while IFS= read line
  do
    test "$line" = "MAKE-HERE" && break
    test -n "${header-}" || {
      case "$line" in "#"* ) continue;; * ) header=1;; esac
    }
    line="$(echo "$line" | sed 's/%/%%/g')"
    make_scriptbody="$make_scriptbody\n$line"
  done
  local f=
  while true
  do
    IFS= read line || break
    test -n "$line" || continue
    case "$line" in main[-_]* )
        f=$(echo $line | cut -c6- | tr '-' '_') ; continue ;; esac
    test -z "$f" && {
      main_env="${main_env-}$line "
    } || {
      eval "test -n \"\${main_$f-}\" &&
        main_${f}=\"\${main_$f-}$'\n'\$line\" ||
        main_${f}=\"\$line\""
    }
  done
}

# param Echo 0: rewritten file 1:variables only 2:script w/o directives
make_preproc_script() # Make-Script ~ [Echo]
{
  test -n "${1-}" || set -- 0
  local line cont=0 f= v
  # Keep the exact formatting, requires to parse line-continuations by hand
  while IFS=$'\n' read -r line
  do
    test $cont -eq 1 && {
      test -n "$f" && {
        case "$line" in *'\' ) end=0 ;; * ) end=1;; esac
        test $end -eq 1 ||
            line="$(echo "$line" | cut -c1-$(( ${#line}-1 )) )"
        printf -v v '%s\n%s' "$v" "$line"
        test $end -eq 0 || {
            test $1 -eq 0 -o $1 -eq 1 && {
                printf "%s='%s'\n" "${f}" "${v}"
            }
            cont=0; f=; unset v
        }
        continue
      } || {
        test $1 -ne 0 -a $1 -ne 2 || echo "$line"
        case "$line" in *\ ) cont=1 ;; * ) cont=0 ;; esac
        continue
      }
    }

    case "$line" in *'\' ) cont=1 ;; * ) cont=0 ;; esac

    case "$line" in
        main[-_]*" "* )
                f="$(echo "$line" | cut -d' ' -f1 | tr '-' '_')"
                test $cont -eq 1 &&
                    line="$(echo "$line" | cut -c1-$(( ${#line}-1 )) )"
                v="$(echo "$line" | cut -d' ' -f2-)"
                test $cont -eq 1 || {
                    test $1 -eq 0 -o $1 -eq 1 && {
                        printf "%s='%s'\n" "${f}" "${v}"
                    }
                }

            ;;
        '#!'* ) test $1 -ne 0 -a $1 -ne 2 ||
                    echo '#!/usr/bin/env bash';;
        * ) test $1 -ne 0 -a $1 -ne 2 || echo "$line";;
    esac

  done
}

make_here()
{
  local make_script make_scriptname make_scriptbody
  make_script=$1
  make_scriptname=$(basename "$1" .sh)
  base=

  local main_local main_env main_lib main_load main_unload main_load_flags main_unload_flags main_epilogue CWD

  test -n "${make_pref-}" || {
      test ${make_echo-0} -eq 0 && {
          local make_pref=eval
      } || make_pref=echo
  }

  make_read_herescript < "$1"
  $make_pref "$(printf "$make_scriptbody")"

  main_script=$make_script
  main_base=$make_scriptname
  main_scriptpath="$(dirname "$make_script")"

  eval "${main_env-} \
    main_make $make_scriptname"
  shift
  test ${make_echo-0} -eq 0 || echo
  main_entry "$@"
}

make_preproc()
{
  local make_script make_scriptname base
  make_script=$1
  make_scriptname=$(basename "$1" .sh)
  local vid; mkvid $make_scriptname; base=$vid

  local main_env main_local main_env main_lib main_load main_unload main_load_flags main_unload_flags main_epilogue CWD

  test -n "${make_pref-}" || {
      test ${make_echo-0} -eq 0 && {
          local make_pref=eval
      } || make_pref=echo
  }
  test ${make_echo-0} -eq 1 && {
      make_preproc_script 2 < "$1"
      eval "$( make_preproc_script 1 < "$1" )"
  } || {
      $make_pref "$( make_preproc_script < "$1" )"
  }
  main_script=$make_script
  main_base=$make_scriptname
  main_scriptpath="$(dirname "$make_script")"
  # Create main parts but do not eval yet
  eval "${main_env-} main_make $make_scriptname"
  shift
  test ${make_echo-0} -eq 0 || echo
  main_entry "$@"
}

# Id: script-mpe/0.0.4-dev main-make.lib.sh
