
### Global shell function set ('lib') for this repository

# TODO: move to tool/us/? as part, or lib?
# TODO: derive from tool/u-s/


script_mpe_lib__init ()
{
  export -f sh_notfound sh_errsyn sh_errusr
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized script-mpe.lib" "$(sys_debug_tag)"
}


uc_env +d dx :mkFun '_Sh_Fun_Eval "$@"'

# This is all mostly useless
:mkFun noop :
#:mkFun cite :
:mkFun :ignore '"$@" || true'
:mkFun :keepLast ': "$_"'
:mkFun :keepStatus ': "$?"'
:mkFun :keepArgCount ': "$#"'
:mkFun :keepArgConcat ': "$*"'
:mkFun :keepFirstArg ': "$1"'
:mkFun :wac '"$@"'
:mkFun :wacnz 'test -n "$("$@")" && echo "$_"'


sh_fclone () # ~ <New-name> <Copy-ref> # alias:fun-clone
{
  : source "script-mpe.lib.sh"
  : input "${1:?$FUNCNAME: New function name expected}"
  :pass "$_ () {
$(_Sh_Fun_Body "${2:?sh-fclone: Reference function name expected}")
}" &&
  eval "$_"
}


. "${U_S:?}/tool/sh/part/sh-mode.sh"


# Helper to generate true or false command.
# XXX: [[ ${key:-false} != true ]] || ... seems like a more terse, fitting idiom
std_bool () # ~ <Cmd...> # Print true or false, based on command status
{
  : source "script-mpe.lib.sh"
  "$@" && printf true || {
    [[ 1 -eq $? ]] || BOOL= : ${BOOL:?Boolean status expected: E$_: $*}
    printf false
  }
}
:mkFun bool 'std_bool "$@"'
:mkFun not '! "$@"'

# Boolean-bit: validate 0/1, or return NZ for other arguments. This uses
# std_bool to test for 0 (true) or 1 (false) value, and prints either command.
std_bit ()
{
  : source "script-mpe.lib.sh"
  [[ $# -eq 1 && 2 -gt "${1:-2}" ]] || return ${_E_GAE:-193}
  std_bool test 1 -eq "${1:?}"
}

# XXX: match command status against globspec. not sure how [[ compares to
# case & glob impl. in terms of speed.
std_ifstat () # ~ <Spec> <Cmd...>
{
  : source "script-mpe.lib.sh"
  "${@:2}"
  str_globmatch "$?" "$1"
}

std_noerr ()
{
  : source "script-mpe.lib.sh"
  "$@" 2>/dev/null
}

std_noout ()
{
  : source "script-mpe.lib.sh"
  "$@" >/dev/null
}

std_quiet () # ~ <Cmd...> # Silence all output (std{out,err})
{
  : source "script-mpe.lib.sh"
  "$@" >/dev/null 2>&1
}

std_nz () # ~ <Cmd...> # Require non-zero status. Ie. invert status, fail (only) if command returned zero-status
{
  : source "script-mpe.lib.sh"
  ! "$@"
}

std_verbose () # ~ <Message ...> # Print message
{
  : source "script-mpe.lib.sh"
  >&2 echo "$@" || return 3
}

std_v_exit () # ~ <Cmd ...> # Wrapper to command that exits verbosely
{
  : source "script-mpe.lib.sh"
  "$@"
  stderr_exit $?
}

std_v_stat ()
{
  : source "script-mpe.lib.sh"
  "$@"
  stderr_stat $? "$@"
}
std_v1c_stat () { std_v_stat "$@"; }

std_v1c () # ~ <Cmd ...> # Wrapper that echoes both command and status
{
  : param "<Cmd ...>"
  : note "Strictly for debugging of script branches (or DEBUG, DIAG mode etc)"
  : source "script-mpe.lib.sh"
  >&2 echo "Running command: $*"
  "$@"
  stderr_stat $? "$@"
}
# Copy: std-uc.lib

# standard visual status (on stderr). see also std-nvs
stderr_vs () # ~ <Message ...> # Print message, pass previous status code.
{
  : about "Print message, pass previous status code"
  : param "<Message ...>"
  : source "script-mpe.lib.sh"
  local stat=$?
  >&2 echo "$@"
  return $stat
}
# Copy uc:script/std-uc.lib

# standard non-visual status triggers output non non-zero, also std-vs
std_nvse () # ~ <Message ...> # Pass status code and print message if non-zero
{
  : about "Pass status code and print message if non-zero"
  : param "<Message ...>"
  : source "script-mpe.lib.sh"
  local stat=$?
  [[ $stat -eq 0 ]] || >&2 echo "$@"
  return $stat
}

stderr_exit () # ~ <Status=$?> [<Exit-msg>] [<Nz-exit-msg>] <...> # Verbosely exit passing status code,
# with status message on stderr. See also std-v-exit.
{
  local stat=${1:-$?}
  :pass "$([[ $stat -eq 0 ]] &&
    printf "${2:-"Exiting\\n"}" ||
    printf "${3:-"Exiting (status %i)\\n"}" $stat)" &&
  >&2 echo "$_" ||
    >&2 printf 'Failed formatting status (E%i)\n' "$?"
  exit $stat
}

stderr_v_exit () # ~ <Message> [<Status>] # Exit shell after printing message
{
  : source "script-mpe.lib.sh"
  local stat=$?
  >&2 echo "$1" || return 3
  exit ${2:-$stat}
}

# Like stderr-v-exit, but exits only if status is given explicitly, or else
# if previous status was non-zero.
:mkFun stderr_ '
  local stat=$?
  >&2 echo "$1" || return 3
  test -z "${2:-}" && test 0 -eq "$stat" || exit $_'

# Show whats going on during sleep, print at start and end. Makes it easier to
# find interrupt points for sensitive scripts. Verbose sleep prints to stderr
# and does not listen to v{,verbosity} but does have a verbose mode toggle var
# sleep-v.
stderr_sleep_int ()
{
  : source "script-mpe.lib.sh"
  local last=$_
  : "${sleep_q:=$(bool not ${sleep_v:-true})}"
  ! ${sleep_v:-true} ||
    printf "> sleep $*$(test -z "$last" || >&2 printf " because $last...")"
  fun_wrap command sleep "$@" || {
    [[ 130 -eq $? ]] && {
      "$sleep_q" ||
        >&2 echo " aborted (press again in ${sleep_itime:-1}s to exit)"
      command sleep ${sleep_itime:-1} || return
      return
    } || return $_
  }
  ! ${sleep_v:-true} ||
    >&2 echo " ok, continue run"
}

stderr_stat ()
{
  : source "script-mpe.lib.sh"
  local last=$_ stat=${1:-$?} ref=${*:2}
  : "${ref:-$last}"
  test 0 -eq $stat &&
    printf "OK '%s'\\n" "$ref" ||
    printf "Fail E%i: '%s'\\n" "$stat" "$ref"
  return $stat
}

str_wordmatch () # ~ <Word> <Strings...> # Non-zero unless word appears
{
  : source "script-mpe.lib.sh"
  [[ 2 -le $# ]] || return ${_E_GAE:-193}
  case " ${*:2} " in
    ( *" ${1:?} "*) ;; #  | *" ${1:?} " | " ${1:?} "*) ;;
    ( * ) false ; esac
}

str_vword () # ~ <Variable> [<String>] # Transform string to word
{
  : source "str.lib.sh"
  declare -n v=${1:?}
  : "${2-$v}"
  v="${_//[^A-Za-z0-9_]/_}"
}

# Restrict used characters to 'word' class (alpha numeric and underscore);
# string-util function with optional case conversion.
str_word () # ~ <String> # Transform string to word
{
  : source "str.lib.sh"
  : "${1:?}"
  local out="${_//[^A-Za-z0-9_]/_}"
  [[ "${upper:-false}" != true ]] && {
    [[ "${lower:-false}" != true ]] &&
      echo "$out" ||
      echo "${out,,}"
  } || echo "${out^^}"
}

sh_var ()
{
  : source "script-mpe.lib.sh"
  declare -p "${1:?}" > /dev/null 2>&1
}

sh_var_incr ()
{
  : source "script-mpe.lib.sh"
  local v=${!1:-0}
  declare -g ${1:?}=$(( v + 1 ))
}

# Store given or previous last argument value at variable
sh_var_setval () # ~ <Var-name> [<Value-or-last>]
{
  : source "script-mpe.lib.sh"
  declare -g ${1:?}="${2:-$_}";
}

# Copy value from to new
sh_var_copy () # ~ <New-var> <From-ref>
{
  : source "script-mpe.lib.sh"
  declare -g ${1:?}="${!2}"
}

sh_adef () # ~ <Array> <Key>
{
  : about "Check for array variable, and for value set at key (zerowidth or otherwise)"
  sh_arr "${1:?"$(sys_exc script-mpe.lib:sh-adef@1:array)"}" &&
  : "${1:?}[${2:?"$(sys_exc script-mpe.lib:sh-adef@2:key)"}]" &&
  #[[ "(unset)" != "${!_:-(unset)}" ]]
  [[ ${!_:+set} ]]
  : source "script-mpe.lib.sh"
}

# Call sys-arr unless array var with name exists.
sh_arr_assert () # ~ <Var-name> <Command...>
{
  : source "script-mpe.lib.sh"
  sh_arr "$1" || sys_exec_mapfile "$@"
}

sh_arr_def () # ~ <Var-name>
{
  : source "script-mpe.lib.sh"
  sh_arr "${1:?}" &&
  declare -n arr=${1:?} &&
  test "${arr[*]+set}" = "set"
}

sh_arr_len () # ~ <Var-name>
{
  : source "script-mpe.lib.sh"
  #sh_arr_def "${1:?}" &&
  local -n _arr=${1:?} &&
  [[ ${_arr[*]+set} ]] &&
  echo ${#_arr[@]}
}

sh_arr_nz () # ~ <Var-name>
{
  local -n _arr=${1}
  [[ ${_arr[*]+set} ]]
  #&& [[ ${#_arr[@]} -gt 0 ]]
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
  : source "script-mpe.lib.sh"
  std_noerr "$@" || true
}

# see also sys-callers
sh_caller ()
{
  : source "script-mpe.lib.sh"
  : "$(( ${1:-0} + 1 ))"
  :pass "$(caller $_)" || return
  : "${_#* }"
  : "${_% *}"
  echo "$_"
}

# Read output lines of command onto array, appending after existing items.
# A simple mapfile wrapper that executes command, buffers output, checking
# status and reads zero-len value as line items onto end of array.
sys_exec_mapfile () # ~ <Var-name> <Cmd...> # Read out (lines) from command into array
{
  : source "script-mpe.lib.sh"
  : group util
  : about "Read command standard ouput (lines) into array"
  : extended "Reads onto end for existing array"
  : param "<Array-name> <Cmd...>"
  : src -uconf-shell-core.sh
  : derive sys-exec-mapfile
  : input "${1:?Array-name expected, $ENV_CTX:$FUNCNAME}"
  : input "${2:?Command line expected, $ENV_CTX:$FUNCNAME}"
  local -n _sys_exec_mapfile_arr=${1}
  local outname=${1} offset
  [[ ${_sys_exec_mapfile_arr[*]:+set} ]] &&
  offset=${#_sys_exec_mapfile_arr[@]} || offset=0
  if_ok "$("${@:2}")" &&
  test -n "$_" &&
  <<< "$_" mapfile -O ${offset} ${mapfile_f:--t} ${outname}
}
# Copy: sys.lib.sh

# system-exception-trace: Helper to format callers list including custom head.
sys_exc_trc () # ~ [<Head>] ...
{
  : group debug
  echo "${1:-script-mpe: E$? source trace:}"
  local i
  for (( i=1; 1; i++ ))
  do
    :pass "$(caller $i)" && echo "  - $_" || break
  done
  : source "script-mpe.lib.sh"
}

#
