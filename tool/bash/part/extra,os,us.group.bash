# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# Distributed under terms of the MIT license.

us_os_extra_pre=User-Script.OS.x
us_os_extra_man='

_sh_type

XXX: should probably be using find based expansions everywhere for
multilanguage/multibyte names instead of Bash globbing iirc

XXX: review assert naming convention

assert-*
for verbose test/check routine for diag purposes,
*-assert
for update/modification routines

but dont overuse
'
us_os_extra_cnk=687166b5
us_os_extra_fun=(
  .assert-env
  .command-assert
  .commands-list
  .count-lines
  .expand-pathref
  .iter-sources

  .lookup-expand{,-commands}
  .lookup-expand-{leafs,{path,dir}tree}
  .lookup-expand-safe{,names}
  .lookup-list
  .local-lookup-list
  .first-status
  .script-table
  .symlink-assert
  .tempfile
  .unique-{lines,paths}
  .with-local{,-noctx}
)
declare -gA \
us_os_extra_als=(
  [assert_absolute]=.assert-absolute-path
  [assert_command]=.command-assert
  [assert_env]=.assert-env
  [assert_symlink]=.symlink-assert
  [cwd.lookup-list]='.local-lookup-list $PWD'
  [line_count]=.count-lines
  [list_execs]=.commands-list
  [list_execsafe]=PATH+execs
  [list_paths]=PATH+names
  [list_sources]=PATH+leafs
  [list_path_sources]=.lookup-expand-leafs
  [list_sources]=PATH+leafs
  [mkdirs]='>&2 mkdir -vp'
  [lookup.tree]='.lookup-expand-pathtree'
  ["PATH+execs"]='.lookup-expand-commands PATH'
  ["PATH+names"]='.lookup-expand-safenames PATH'
  ["PATH+lines"]='.lookup-list PATH'
  ["PATH+leafs"]='.lookup-expand-leafs PATH'
  [path.tree]='.lookup-expand-pathtree PATH'
  [path.list]=PATH+lines
  [path.commands]='.lookup-expand-commands PATH'
  [us_tempfile]=.tempfile
  [remove_dupes]=awk\ \''!a[$0]++'\'
  [remove_dupes_and_current]='awk '\''{
  if (!a[$0]++) {
    if ($0 == ".") next
    print $0
  }
  endif
}'\'''
  [remove_dupes_or_hidden]='awk '\''{
  if (!a[$0]++) {
    if (substr($0, 1, 1) == ".") next
    print $0
  }
}'\'''
  ["script.status"]='.script-status'
  ["script.loaded"]='.script-list'
  [symlink_assert]=.symlink-assert
  ["SCRIPTPATH+names"]='.lookup-expand SCRIPTPATH'
  ["SCRIPTPATH+lines"]='.lookup-list SCRIPTPATH'
  ["SCRIPTPATH+leafs"]='.lookup-expand-leafs SCRIPTPATH'
  [us_count_lines]=.count-lines
  [with_local]=.with-local
  [with_local_noctx]=.with-local-noctx
)
declare -gA \
us_os_extra_ssc=(
  ['.assert-absolute-path']='local path=${1:?}
[[ ${path:0:1} == / ]] ||
  failerr "${2:-Absolute path expected}"'
  ['.script-list']='printf "%s\n" "${!_os_script_path[@]}"'
  ['.script-path-list']='printf "%s\n" "${_os_script_path[@]}"'
  ['.script-ok']='eval "! (( 0 $(printf "+ %i" "${_os_script_load[@]}") ))"'
  ['.script-status']='.first-status _os_script_load'
  ['.script-tab']='.script-table _os_script_path _os_script_load'

  # TODO: generate some dedicated lib with all these
  [test_array_ne]=\
': input "${1:?Env key name}"
local -n _arr=${1}
[[ ${_arr:+set} && ${_arr[@]:+set} ]] ||
  failerr "Expected array: $1"'

)
declare -gA \
us_os_extra_hooks=(
#  [init]=\
#''
)

User-Script.OS.x.assert-env ()
{
: param '~ <Status> <Key> <Test>'
: about 'Test value in the environment and report verbosely'
: input "${1:?$FUNCNAME${*:+ $*}: Unexpected status}"
: input "${2:?$FUNCNAME${*:+ $*}: Environment name}"
: input "${3:?$FUNCNAME${*:+ $*}: Test command}"
  local -n _env_val=$2
  "$3" "$_env_val" ||
    failerr "E$? validating env $2" $1
}

User-Script.OS.x.command-assert ()
{
: about 'See that command exists, but normally just once per session'
: extended 'Util for scripts to track paths to executables, like Bash hash builtin'
: param '~ <Command-ref> [<PATH-varname>] ...'
  local exec{name,path,ref} pathref=${2:-PATH}
  execname=${1//[^A-Za-z0-9_]/_}
  local -n path=${pathref} envref="${execname}_bin"
  [[ ${envref:+set} ]] || {
    execref=${1}
    [[ ${execref:0:1} == / ]] &&
    execpath=$execref || {
      execpath=$(PATH=$path command -v "${execref}") ||
        failerr "No such ${execref@Q} command executable file found on path" ||
          return
    }
    [[ -x "$execpath" ]] ||
      failerr "Not an executable file ${execpath@Q}" || return
    envref=$execpath
  }
}

User-Script.OS.x.commands-list ()
{
: param '~ [<PATH-var>] [<Match...>]'
: about 'Simple Bash glob iterating over PATH-var elements'
: extended 'See lookup-expand-commands for dealing with nonsafe names'
  local pathvar=${1:-PATH} paths
  : "${!pathvar}"
  mapfile -t paths <<< "${_//:/$'\n'}"
  shift
  local sub path
  for path in "${paths[@]}"
  do
    for sub in $path/${1:-*}
    do
      [[ -x "$sub" ]] || continue
      echo "${sub##*/}"
    done
  done
}

User-Script.OS.x.count-lines ()
{
: param '~ [<Input>]'
: about 'Count lines with wc (no EOF termination correction)'
: export line_count
  if_ok "$(wc -l "$@")" &&
  echo "${_%% *}"
}

User-Script.OS.x.expand-pathref ()
{
: param '~ <Var>'
  local -n _us_os_pathref=${1}
  while true
  do
    case "$_us_os_pathref" in
      ( "~" )
          _us_os_pathref=${HOME:?}
        ;;
      ( "~/"* )
          _us_os_pathref=${HOME:?}${_us_os_pathref:1}
        ;;
      ( *"$"* )
          [[ $_us_os_pathref =~ \$([A-Za-z_][A-Za-z0-9_]+) ]] && replace='$'${BASH_REMATCH[1]} || {
            [[ $_us_os_pathref =~ \${([^}]+)} ]] && replace='${'${BASH_REMATCH[1]}'}' ||
              failerr "Failed matching var for ${_us_os_pathref}" || return
          }
          local -n varref=${BASH_REMATCH[1]}
          _us_os_pathref=${_us_os_pathref//"$replace"/"$varref"}
        ;;
      ( * ) return
    esac
  done
}

User-Script.OS.x.first-status ()
{
  # XXX: may want to group this with some apply* helper set
: input "${1:?$FUNCNAME${*:+ $*}: Status map}"
  local -n _687166b5_stats1=${1}
  local _687166b5_stat1
  for _687166b5_stat1 in "${_687166b5_stats1[@]}"
  do
    ! ((_687166b5_stat1)) || return ${_687166b5_stat1}
  done
}

User-Script.OS.x.iter-sources ()
{
: about 'Helper to iterate over specific parts'
: extended 'This is mostly to explore usage of data, see also iter-parts'
  # This combines iterator and iteratee's in one select, but thats besides the
  # point here.

  local -I US_SCR_{PATH,HASH,EXT}
  : "${US_SCR_PATH:=$SCRIPTPATH}"
  : "${US_SCR_HASH:=_os_script_path}"
  : "${US_SCR_EXT:=.group.bash .bash}"

  case ${1:?} in

  ( --call )
      (($#-1)) || return ${_E_MA:?}
      "${@:2}"
    ;;

  ( --from-map )
      (($#-2)) || return ${_E_MA:?}
      : input "${2?$FUNCNAME${*:+ $*}: Part hash}"
      local -n _32591e26_map1=${2}
      case "${3}" in
      ( --all )
          local -a matches
          ! ((${#_32591e26_map1[@]})) || matches=( "${!_32591e26_map1[@]}" )
          User-Script.OS.x.iter-sources "${@:4}"
        ;;

      ( --keys )
          User-Script.OS.x.iter-sources "${@:1:2}" --all --matches "${@:4}"
        ;;

      ( --match )
          (($#-3)) || return ${_E_MA:?}
          local -a matches
          local key km offset=0
          for km in "${@:4}"
          do
            ((offset+=1))
            [[ ${km:0:1} != - ]] || break
          done
          for key in "${!_32591e26_map1[@]}"
          do
            for km in "${@:4:offset}"
            do
              User-Script.String.globmatch "${km}" "${key}" || continue
              matches+=( "$key" )
            done
          done
          User-Script.OS.x.iter-sources "${@:3+offset}"
        ;;

        * ) return ${_E_nsk:-67}
      esac
    ;;

  ( --loaded )
      (($#-1)) || return ${_E_MA:?}
      User-Script.OS.x.iter-sources --from-map "$US_SCR_HASH" "${@:2}"
    ;;

  ( --matches )
      ! ((${#matches[@]})) || printf '%s\n' "${matches[@]}"
    ;;

  ( --on-path )
      (($#-1)) || return ${_E_MA:?}
      case "${2}" in
      ( --all )
          # XXX: see FIXME, should reset US_SCR_EXT to sensible value here
          User-Script.OS.x.iter-sources --on-path --match '*' "${@:3}"
        ;;

      ( --match )
          (($#-2)) || return ${_E_MA:?}
          local -a bases paths matches
          mapfile -t bases <<< "${US_SCR_PATH//:/$'\n'}"
          local base ext pm script offset=0
          for pm in "${@:3}"
          do
            ((offset+=1))
            [[ ${pm:0:1} != - ]] || break
          done
          for base in "${bases[@]}"
          do
            for pm in "${@:3:offset}"
            do
              # FIXME: nested looping this way (using glob) necissarily yields
              # all extensions, even if they overlap (ie. produce duplicate
              # matches)
              for ext in ${US_SCR_EXT//[: ]/$'\n'}
              do
                for script in "${base}"/${pm}${ext}
                do
                  scriptname=${script:${#base}+1}
                  User-Script.String.globmatch "${pm}" "${scriptname}" || continue
                  matches+=( "$scriptname" )
                  paths+=( "$script" )
                done
              done
            done
          done
          User-Script.OS.x.iter-sources "${@:2+offset}"
        ;;

        * ) return ${_E_nsk:-67}
      esac
    ;;

  ( --paths )
      ! ((${#paths[@]})) || printf '%s\n' "${paths[@]}"
    ;;

    * ) return ${_E_nsk:-67}
  esac
}

User-Script.OS.x.lookup-expand ()
{
: about 'A group of functions for expanding path and filename "globs"'
: extended 'The -safenames and other variants use find to avoid any issues with
newlines in names. For native expansions the lookup-expand can resolve patterns
for one or more base directories. '
: param ' ~ <Lookup-path-var> <Output-array-var-> [<Globs...>]'
  local _bd _print=0 _arr _offset _globs _g
  local -n _lookup=${1:?$FUNCNAME: Name expected for input variable, $ENV_CTX}
  [[ ! ${2:+set} ]] && _print=1 ||
    local _dest=${2:?$FUNCNAME:$1: Name expected for output variable, $ENV_CTX}
  [[ ! ${3:+set} ]] && _globs=( '*' ) || _globs=( "${@:3}" )
  local -a _paths _dlines
  mapfile -t _paths <<< "${_lookup//:/$'\n'}" &&
  [[ ${_paths[*]:+set} ]] &&
  for _bd in "${_paths[@]}"; do
    for _g in "${_globs[@]}"; do
      _dlines+=( "${_dest}+=( \"$_bd/\"$_g )" )
    done
  done &&
  . <(printf '%s\n' "${_dlines[@]}")
}

User-Script.OS.x.lookup-expand-commands ()
{
: about 'Variant for lookup-expand-safenames to list executable files'
: param ' ~ <Lookup-path-var> [<Output-var>] ...'
  local -a _find_cmds=( -maxdepth 1 -not -type d -executable -printf '%P\n' )
  User-Script.OS.x.lookup-expand-safenames "$1" "$2" _find_cmds
}

User-Script.OS.x.lookup-expand-leafs ()
{
: about 'Variant for lookup-expand-safenames to list any non-directory path'
: param ' ~ <Lookup-path-var> [<Output-var>] ...'
  local -a _find_paths=( -maxdepth 1 -not -type d )
  User-Script.OS.x.lookup-expand-safenames "$1" "$2" _find_paths
}

User-Script.OS.x.lookup-expand-dirtree ()
{
: about 'Variant for lookup-expand-safenames'
: param ' ~ <Lookup-path-var> [<Output-var>] ...'
  local -a _find_dirtree=( -type d -not -path '*/.*' )
  User-Script.OS.x.lookup-expand-safenames "$1" "$2" _find_dirtree
}

User-Script.OS.x.lookup-expand-pathtree ()
{
: about 'Variant for lookup-expand-safenames'
: param ' ~ <Lookup-path-var> [<Output-var>] ...'
  local -a _find_pathtree=( -not -path '*/.*' )
  User-Script.OS.x.lookup-expand-safenames "$1" "$2" _find_pathtree
}

User-Script.OS.x.lookup-expand-safe ()
{
  TODO "Read to arrays for safe handling of anything"
}

User-Script.OS.x.lookup-expand-safenames ()
{
: param ' ~ <Lookup-path-var> [<Output-var>] [<Find-filter-argv-var>]'
: about 'List names found through lookup'
: extended 'Wrapper for find that iterates lookup path and print or assigns result'
: extended 'Appends result list to string or array variable, or prints it if none is given'
  local _bd _print=0 _arr _offset
  local -n _lookup=${1:?$FUNCNAME: Name expected for input variable, $ENV_CTX}
  [[ ! ${2:+set} ]] && _print=1 || {
    local -n _dest=${2:?$FUNCNAME:$1: Name expected for output variable, $ENV_CTX}
    # XXX: cannot easily figure out var scope, so this name might be local...
    local -n _vartype="us_shell_tspec[$2]"
    User-Script.Shell.variable-type "$2" || return
    case "${_vartype}" in -a ) _arr=1
        [[ ${_dest[*]:+set} ]] && _offset=${#_dest[*]} || _offset=0
      ;; * ) _arr=0 ;; esac
  }
  [[ ! ${3:+set} ]] &&
    local -a _find_filter=( -maxdepth 1 -not -type d -printf '%P\n' ) ||
    local -n _find_filter=${3:?}
  local -a _paths
  mapfile -t _paths <<< "${_lookup//:/$'\n'}" &&
  [[ ${_paths[*]:+set} ]] &&
  for _bd in "${_paths[@]}"
  do
    if_ok "$(find "$_bd" "${_find_filter[@]}")" &&
    test -n "$_" || continue
    ((_print)) && echo "$_" || {
      ((_arr)) && {
        mapfile -O $_offset -t $2 <<< "$_" || return
      } ||
        # String concatenation uses newlines for separator
        _dest=${_dest:+$_dest$'\n'}${_}
    }
  done
}

User-Script.OS.x.local-lookup-list ()
{
  : param '[<Path=PWD>] [<Dest>]'
  : about 'Generate lookup sequence for path and all its directories'
  local path=${path:-$PWD} sub
  [[ ${2:+set} ]] &&
  local -n _us_os_lll=${2} || local _us_os_lll
  _us_os_lll+="$path"$'\n'
  until [[ ! ${path:+set} ]]
  do
    path="${path%/*}"
    _us_os_lll+="${path:-/}"$'\n'
  done
  [[ ${2:+set} ]] || printf '%s' "$_us_os_lll"
}

User-Script.OS.x.lookup-list ()
{
  : param '<Seq-var> [<Dest>]'
  : about 'List lookup sequence string (ie. : colon separated) as lines'
  local -n _lookup=${1:?}
  local liststr="${_lookup//:/$'\n'}"
  (($#-1)) && {
    User-Script.Shell.byname-set-value "${2}" "$liststr" || return
  }
  echo "$liststr"
}

User-Script.OS.Process.parent ()
{
: param '~ [<PID>] [<Ps-argv>] [<Outvars...>]'
  local _us_os_out{,v}
  ! (($#-2)) && _us_os_outv=( _us_os_out ) || _us_os_outv=( "${@:3}" )
  if_ok "$(ps -o ppid= -p ${1:-$$})" &&
  if_ok "$(ps -p $_ ${2:--o pid= -o command=})" &&
  read -r ${_us_os_outv[@]} <<< "$_" && {
    (($#-2)) || echo "$_us_os_out"
  }
}

User-Script.OS.x.script-table ()
{
: input "${1:?$FUNCNAME${*:+ $*}: Hash map}"
: input "${2:?$FUNCNAME${*:+ $*}: Status map}"
  local -n _687166b5_hash1=${1} _687166b5_stats2=${2} _687166b5_hash2 \
    _687166b5_key1='_687166b5_hash1[$_687166b5_als]' \
    _687166b5_key2='_687166b5_hash2[$_687166b5_key1]' \
    _687166b5_stat2='_687166b5_stats2[$_687166b5_key1]'
  local _687166b5_als
  for _687166b5_als in "${!_687166b5_hash1[@]}"
  do
    # XXX: fmts
    #printf '%s\t%i\t%s\n' "$_687166b5_als" "$_687166b5_stat2" "$_687166b5_key1"
    printf '%q %i %s' "$_687166b5_als" "$_687166b5_stat2" "$_687166b5_key1"
    #declare -p _687166b5_als
    #echo $_687166b5_als
    for _687166b5_hash2 in "${@:3}"
    do
      #declare -p _687166b5_{als,hash2,stat2,key1}
      printf '\t%s' "$_687166b5_key2"
    done
    printf '\n'
  done
}

User-Script.OS.x.symlink-assert ()
{
: about 'Assert symbolic link exists for destination, update if possible'
: param '~ <Symlink-Path> <Target>'
  local path="${1:?Symlink path}"
  local dest="${2:?Symlink target path}"
  local curdest vflag

  # Easy reference to identical named target in other directory
  if [[ -d "${path}" && ! -h "${path}" ]]
  then path="${path}/${dest##*/}"
  fi
  if [[ $path != */* ]]
  then
    path=./$path
  fi
  if [[ -h $path ]]
  then
    curdest="$(readlink "$path")"
    [[ $curdest = "${dest}" ]] && return
    : "${path%/*}"
    [[ -w ${_:-$PWD} ]] ||
      failerr "Basedir not writable: ${path@Q}" || return
    rm "$path" || return
  fi
  # XXX: debug level verbosity
  [[ ${verbosity:-5} -lt 7 ]] || vflag=v
  >&2 ln -s${vflag-} "${dest}" "${path}"
}

User-Script.OS.x.tempfile ()
{
: param '~ <Variable> [<Template>] [<Suffix>] ...'
: input "${1:?Variable reference name}"
  local -n _varref=${1}
  _varref=$(mktemp ${3:+--suffix="$3"} --tmpdir ${2:-us-os-tempfile_XXX}) ||
    failerr "E$? getting temporary file"
}

User-Script.OS.x.unique-lines ()
{
: param 'Input-file ...'
: about 'Sort file in place'
: input "${1:?Input}"
  local _tmpfile _stat
  User-Script.OS.x.tempfile _tmpfile us-os-uniquelines_XXX || return
  < "$1" > "$_tmpfile" cat &&
  > "$1" < "$_tmpfile" awk '!a[$0]++' &&
  rm "$_tmpfile"
}

User-Script.OS.x.unique-paths ()
{
: about 'List arguments as is but filter duplicate realpaths'
: XXX unused
  local -A _paths
  local -n _realpath='_paths["$path"]'
  local path
  for path
  do
    [[ ${_realpath:+set} ]] && continue
    _realpath=$(realpath "$path")
    echo "$path"
  done
}

User-Script.OS.x.with-local ()
{
: about 'Declare local variable context and do sub invocation'
: extended 'This is not an export for subcommands, ie. a local command env'
: param '~ <Env=Val...> <Command...>'
# XXX: could make stack with dyn refs. Or just use ~noctx.
  local -A env
  while [[ "$1" == *=* ]]
  do env["${1%%=*}"]=${1#*=}
    shift; done
  local var
  local -n val='env["$var"]'
  for var in "${!env[@]}"
  do declare "$var=$val" || return
  done
  "$@"
}

User-Script.OS.x.with-local-noctx ()
{
: about 'Declare local variable context and invoke sub command'
: param '~ <Env=Val...> <Command...>'
  while [[ "$1" == *=* ]]
  do declare "${1}" || return; shift; done
  "$@"
}

# Id: extra,os,us                                vim:set ft=bash sw=2 sts=2 et:
