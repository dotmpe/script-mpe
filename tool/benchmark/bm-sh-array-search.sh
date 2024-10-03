sh_wordmatch ()
{
  local arg match=${1:?}
  shift
  for arg
  do [[ "$arg" == "$match" ]] && return
  done
  false
}

sh_arr_contains_1 () # ~ <Array-name> <Value>
{
  local item match=${2:?}
  typeset -n arr=${1:?}
  for item in "${arr[@]}"
  do [[ "$item" == "$match" ]] && return
  done
  false
}

sh_arr_contains_2 () # ~ <Array-name> <Value>
{
  typeset match=${2:?}
  typeset -n arr=${1:?}
  printf '%s\0' "${arr[@]}" | grep -F -x -z -- "^$match$"
}

sh_arr_to_tab () # ~ <From-array> <To-array>
{
  typeset -n from=${1:?}
  typeset item toname=${2:?}
  declare -gA "${toname}=()"
  for item in "${!from[@]}"
  do
    declare -g "${toname}[${from[$item]}]="
  done
}

sh_table_contains_1 () # ~ <Associative-array> <Match>
{
  typeset -n arr=${1:?}
  test -n "${arr["${2:?}"]+set}"
}

sh_table_contains_2 () # ~ <Associative-array> <Match>
{
  typeset ref="${1:?}[${2:?}]"
  test -n "${!ref+set}"
}

source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

runs=100

report ()
{
  report_time "${1:-$_}" runs=$runs samples=10 load:$(less-uptime g 3) host:$HOST
}

samples=10
#test_baseline $samples $runs
#report baseline

lib_load os

if_ok "$(read_nix_style_file test/var/urls1.list)" &&
<<< "$_" mapfile -t urls

time run_all $runs -- sh_arr_contains_1 urls "https://www.wikiwand.com/en/Common_kestrel"

time run_all $runs -- sh_arr_contains_2 urls "https://www.wikiwand.com/en/Common_kestrel"

sh_arr_to_tab urls table

time run_all $runs -- sh_table_contains_1 table "https://www.wikiwand.com/en/Common_kestrel"
time run_all $runs -- sh_table_contains_2 table "https://www.wikiwand.com/en/Common_kestrel"

#
