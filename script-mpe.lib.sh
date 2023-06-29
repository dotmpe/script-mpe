
### Global shell function set ('lib') for this repository


fun_def () { eval "$1 () { ${*:2} }"; }
# Could declare all fun-* this way, but what is the point atm. May be if fun-
# def tracked metadata. See env-*. Keeping aliases together with fun-*() copy.
#fun_def fun_false false\;
#fun_def fun_keeparg ': "${1:-}";'
# XXX: commented: unused
#fun_false () { false; }
fun_keeparg () { : "${1:-}"; }
fun_keeplast () { : "$_"; }
#fun_statpass () { return; }
fun_def if_ok return\;
fun_true () { :; }
fun_def noop :\;
fun_def cite :\;
fun_wrap () { "$@"; }


LOG_error_handler ()
{
  local r=$? lastarg=$_
  $LOG error ":on-error" "In command '${0}' ($lastarg)" "E$r"
  exit $r
}
# Copy: LOG-error-handler

sh_mode ()
{
  test $# -eq 0 && {
    # XXX: sh-mode summary: flags and list traps
    echo "$0: sh-mode: $-" >&2
    trap >&2
  } || {
    while test $# -gt 0
    do
      case "${1:?}" in

          ( dev )
                sh_mode_exc $opt log-error "$@"
                set -hET &&
                shopt -s extdebug &&
                . "${U_C}"/script/bash-uc.lib.sh &&
                trap 'bash_uc_errexit' ERR || return
              ;;

          ( log-error )
                sh_mode_exc $opt dev "$@"
                set -CET &&
                trap "LOG_error_handler" ERR || return
              ;;

          ( mod )
                  sh_mode strict log-error &&
                  shopt -s expand_aliases
              ;;

          ( strict )
                  set -euo pipefail -o noclobber
              ;;

          ( isleep ) # Setup interruptable, verbose sleep command (for batch scripting)

                  trap '{ return $?; }' INT
                  # Override sleep with function
                  fun_def sleep stderr_sleep_int \"\$@\"\;
              ;;

      esac
      shift
    done
  }
}
# Copy: sh-mode

str_globmatch () # ~ <String> <Glob-pattern>
{
  case "${1:?}" in ${2:?} ) ;; ( * ) false ;; esac
}
fun_def fnmatch 'str_globmatch "${2:?}" "${1:?}";'

std_bool () # ~ <Cmd...> # Print true or false, based on command status
{
  "$@" && printf true || {
    test 1 -eq $? || BOOL= : ${BOOL:?Boolean status expected: E$_: $*}
    printf false
  }
}
fun_def bool 'std_bool "$@";'
fun_def not '! "$@";'

std_ifstat () # ~ <Spec> <Cmd...>
{
  "${@:2}"
  str_globmatch "$?" "$1"
}

std_noerr ()
{
  "$@" 2>/dev/null
}

std_noout ()
{
  "$@" >/dev/null
}

std_stat () # ~ <Cmd...> # Invert status, fail (only) if command returned zero-status
{
  ! "$@"
}

std_quiet () # ~ <Cmd...> # Silence all output (std{out,err})
{
  "$@" >/dev/null 2>&1
}

std_v_exit ()
{
  "$@"
  # XXX: even more verbose... stderr_stat $? "$@"
  stderr_exit $?
}

std_v_stat ()
{
  "$@"
  stderr_stat $? "$@"
}

stderr ()
{
  "$@" >&2
}

stderr_exit ()
{
  local stat=${1:-$?}
  test 0 -eq $stat &&
    printf 'Exiting\n' ||
    printf 'Exiting (status %i)\n' $stat
  exit $stat
}

# Show whats going on during sleep, print at start and end. Makes it easier to
# find interrupt points for sensitive scripts. Verbose sleep prints to stderr
# and does not listen to v{,verbosity} but does have a verbose mode toggle var
# sleep-v.
stderr_sleep_int ()
{
  local last=$_
  : "${sleep_q:=$(bool not ${sleep_v:-true})}"
  ! ${sleep_v:-true} ||
    printf "> sleep $*$(test -z "$last" || printf " because $last...")" >&2
  fun_wrap command sleep "$@" || {
    test 130 -eq $? && {
      "$sleep_q" ||
        echo " aborted (press again in ${sleep_itime:-1}s to exit)" >&2
      command sleep ${sleep_itime:-1} || return
      return
    } || return $_
  }
  ! ${sleep_v:-true} ||
    echo " ok, continue run" >&2
}

stderr_stat ()
{
  local last=$_ stat=${1:-$?} ref=${*:2}
  : "${ref:-$last}"
  test 0 -eq $stat &&
    printf "OK '%s'\\n" "$ref" ||
    printf "Fail E%i: '%s'\\n" "$stat" "$ref"
  return $stat
}

#
