
### Global shell function set ('lib') for this repository

# TODO: move to tools/us/? as part, or lib?
# TODO: derive from tools/u-s/


script_mpe_lib__init ()
{
  export -f sh_notfound sh_errsyn sh_errusr
}


# sh_func_decl
fun_def () {
  : "${2:?fun-def: $1: Function body expected}"
  : "${1:?fun-def: Function name expected} () { ${*:2} }"
  eval "$_"
}

# Could declare all fun-* this way, but what is the point atm. May be if fun-
# def tracked metadata. See env-*. Keeping aliases together with fun-*() copy.
#fun_def fun_false false\;
#fun_def fun_keeparg ': "${1:-}";'
# XXX: commented: unused
#fun_false () { false; }
fun_keep1 () { : "${1:-}"; }
fun_keep () { : "$_"; }
fun_stat () # ~ <...> # alias:if-ok
{ return; }
fun_def if_ok return\;
fun_true () { :; }
fun_def noop :\;
#fun_def cite :\;
fun_w1c () { "$@"; }
fun_w1cnz () { test -n "$("$@")" && echo "$_"; }

ignore () { "$@" || true; }

sh_funbody () # ~ <Ref-fun> <...> # alias:sh-fbody,fun-body
{
  : "${1:?sh-funbody: Function name expected}"
  if_ok "$(declare -f "$_")" || return
  : "${_#* () }"
  : "${_:4:-2}"
  #: "${c#* () $'\n'}"
  #: "${_#\{ $'\n'}"
  #: "${_%$'\n'\}}"
  echo "$_"
}

sh_fclone () # ~ <New-name> <Copy-ref> # alias:fun-clone
{
  : "${1:?sh-fclone: New function name expected}"
  if_ok "$_ () {
$(sh_funbody "${2:?sh-fclone: Reference function name expected}")
}" &&
  eval "$_"
}


. "${U_S:?}/tools/sh/parts/sh-mode.sh"


str_globmatch () # ~ <String> <Glob-pattern>
{
  case "${1:?}" in ${2:?} ) ;; ( * ) false ;; esac
}
fun_def fnmatch 'str_globmatch "${2:?fnmatch: \$2 not set}" "${1:?fnmatch: \$1 not set}";'

str_wordmatch () # ~ <Word> <Strings...> # Non-zero unless word appears
{
  [[ 2 -le $# ]] || return ${_E_GAE:-193}
  case " ${*:2} " in
    ( *" ${1:?} "*) ;; #  | *" ${1:?} " | " ${1:?} "*) ;;
    ( * ) false ; esac
}

# Helper to generate true or false command.
std_bool () # ~ <Cmd...> # Print true or false, based on command status
{
  "$@" && printf true || {
    [[ 1 -eq $? ]] || BOOL= : ${BOOL:?Boolean status expected: E$_: $*}
    printf false
  }
}
fun_def bool 'std_bool "$@";'
fun_def not '! "$@";'

# Boolean-bit: validate 0/1, or return NZ for other arguments. This uses
# std_bool to test for 0 (true) or 1 (false) value, and prints either command.
std_bit ()
{
  [[ $# -eq 1 && 2 -gt "${1:-2}" ]] || return ${_E_GAE:-193}
  std_bool test 1 -eq "${1:?}"
}

# XXX: match command status against globspec.
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

std_quiet () # ~ <Cmd...> # Silence all output (std{out,err})
{
  "$@" >/dev/null 2>&1
}

std_nz () # ~ <Cmd...> # Require non-zero status. Ie. invert status, fail (only) if command returned zero-status
{
  ! "$@"
}

std_verbose () # ~ <Message ...> # Print message
{
  stderr echo "$@" || return 3
}

std_v_exit () # ~ <Cmd ...> # Wrapper to command that exits verbosely
{
  "$@"
  stderr_exit $?
}

std_v_stat ()
{
  "$@"
  stderr_stat $? "$@"
}

std_vs () # ~ <Message ...> # Print message, but pass previous status code.
{
  local stat=$?
  stderr echo "$@" || return 3
  return $stat
}

stderr () # ~ <Cmd <...>>
{
  "$@" >&2
}

stderr_exit () # ~ <Status=$?> <...> # Verbosely exit passing status code,
# with status message on stderr. See also std-v-exit.
{
  local stat=${1:-$?}
  stderr echo "$([[ 0 -eq $stat ]] &&
    printf 'Exiting\n' ||
    printf 'Exiting (status %i)\n' $stat)" "$stat"
  exit $stat
}

stderr_v_exit () # ~ <Message> [<Status>] # Exit shell after printing message
{
  local stat=$?
  stderr echo "$1" || return 3
  exit ${2:-$stat}
}

# Like stderr-v-exit, but exits only if status is given explicitly, or else
# if previous status was non-zero.
fun_def stderr_ \
  local stat=\$?\;\
  stderr echo \"\$1\" "||" return 3\;\
  test -z \"\${2:-}\" "&&" test 0 -eq \"\$stat\" "||" exit \$_\;

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
    [[ 130 -eq $? ]] && {
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

sh_var_incr ()
{
  local v=${!1:-0}
  declare -g ${1:?}=$(( v + 1 ))
}

# Store given or previous last argument value at variable
sh_var_setval () # ~ <Var-name> [<Value-or-last>]
{
  declare -g ${1:?}="${2:-$_}";
}

# Copy value from to new
sh_var_copy () # ~ <New-var> <From-ref>
{
  declare -g ${1:?}="${!2}"
}

# Check for array variable, and for value set at key (zerowidth or otherwise)
sh_adef () # ~ <Array> <Key>
{
  sh_arr "${1:?}" &&
  : "${1:?}[${2:?}]" &&
  test "(unset)" != "${!_:-(unset)}"
}

# Call sys-arr unless array var with name exists.
sh_arr_assert () # ~ <Var-name> <Command...>
{
  sh_arr "$1" || sys_arr "$@"
}

sh_arr_def () # ~ <Var-name>
{
  sh_arr "${1:?}" &&
  declare -n arr=${1:?} &&
  test "${arr[*]+set}" = "set"
}

sh_arr_len () # ~ <Var-name>
{
  #sh_arr_def "${1:?}" &&
  declare -n arr=${1:?} &&
  test "${arr[*]+set}" = "set" &&
  echo ${#arr[@]}
}

sh_fclone inc sh_var_incr
sh_fclone vfrom sh_var_copy
sh_fclone vset sh_var_setval

# Status for missing commands and params
sh_notfound ()
{
  test 127 -eq $?
}

sh_errsyn ()
{
  test 2 -eq $?
}

sh_errusr ()
{
  test 1 -eq $?
}

sh_noerr ()
{
  std_noerr "$@" || true
}

sh_caller ()
{
  : "$(( ${1:-0} + 1 ))"
  if_ok "$(caller $_)" || return
  : "${_#* }"
  : "${_% *}"
  echo "$_"
}

sys_arr () # ~ <Var-name> <Cmd...> # Read out (lines) from command into array
{
  if_ok "$("${@:2}")" &&
  <<< "$_" mapfile -t "$1"
}

# system-exception-trace: Helper to format callers list including custom head.
sys_exc_trc () # ~ [<Head>] ...
{
  echo "${1:-script-mpe: E$? source trace:}"
  for (( i=1; 1; i++ ))
  do
    if_ok "$(caller $i)" && echo "  - $_" || break
  done
}

error_handler ()
{
  test $# -gt 0 || return ${_E_GAE:-3}
  test $# -eq 1 && {
    echo "$1"
    return
  }
  test $# -eq 2 && {
    echo "$1"
    return $2
  }
}

#
