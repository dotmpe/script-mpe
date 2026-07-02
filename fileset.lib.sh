## Files: Listing and filtering by name, or descriptor

# Files are blobs or streams with associated name, path and descriptor (inode,
# times, permissions). Possibly extended attributes.

fileset_lib__load ()
{
  : "${package_lists_files:="scm"}"
}

fileset_lib__init ()
{
  . <(echo 'fileset_list_local ()
{
  $LOG debug "" "Files list local..." "$package_lists_files"
  fileset ${package_lists_files} "$@"
}')
}

fileset_local=( find . )
fileset_local_all=( find -L . )

# XXX:
fileset ()
{
  while [[ $# -gt 0 ]]
  do case "${1:?}" in
        default|local|package ) fileset_list_local "$@"  ;;

        all|find ) false # TODO: use find to list files
            ;;

        in-tag ) false # TODO: use tasks/contexts or other index
            ;;

        media|binary|document|plain|archive|compressed|audio|video|image|other|no-audio|no-video )
            us_part $usp_opts uc-media-extensions uc-media &&
            uc_media_find --$1
          ;;

        scm|tracked ) vc_tracked "$@" ;;

        scm-all )
            vc_tracked "$@"
            vc_untracked "$@" ;;

        * ) error "files-list: Unknown src-set name '$srcset'" 1 ;;
    esac &&
      shift
  done
}

fileset_build_extquery ()
{
: param '~ <Destination-array> <Source-arrays...>'
  local -n _qdest=${1:?} _exts
  if [[ ! ${_qdest[*]:+set} ]]; then
    declare -ga "${1}"
    _qdest=( -false )
  fi
  shift
  local ext
  for _exts
  do
    for ext in "${_exts[@]}"
    do
      _qdest+=( -o -iname "*.$ext" )
    done
  done
}

fileset_create_filter ()
{
  # FIXME: accept add-suf-arrs instead of having to pre-build suffix arrays
: param '(Fileset-Tag) ~ Field-key Exclude-paths -suffixes -suffix-suffixes [additional-suffix-arrays]'
  local _exclude _suf
  declare -ga ${FILESET_TAG}_${1}
  local -n __filter=${FILESET_TAG}_${1}
  local -n __not_paths=${2}
  local -n __not_suf=${3}
  __filter=( "${__not_paths[@]}" "${__not_suf[@]}" )
  local -n __not_sufsuf=${4}
  for _exclude in "${__not_suf[@]}"
  do
    for _suf in "${__not_sufsuf[@]}"
    do
      __filter+=( "$_exclude$_suf" )
    done
  done
}

fileset_filter ()
{
: param '~ <Generator-command-array> <Exclude-tags-array> <Path-match-tags...>'
: about 'Generate find query looking for each tag'
: extended 'Wrapper using find -ipath, tags get surrounded with two wildcards (asterisks) unless one is already found'
: extended 'Tags can words or have a single character (?) and character range ([a-z0-9]) placeholders'
: extended 'The generator is a subcommand that invokes find and passes the filter arguments'
: example '~ "" dev priv   # Return all paths with either dev or priv'
: example '~ "" dev+priv   # Return all paths with both dev and priv'
: example '~ "" dev !priv  # Return all paths with dev, excluding those with priv'
# TODO: want to add flag to switch case-sensitivity mode but dont need it rn
  local arg tag q=( -type f -not -empty '(' -false ) not
  # GNU find filters by default are AND, ie. implied -a. The not items here will
  # be put in a subgroup starting with -false and include OR to make one filter
  # match to succeed, while the main argument sequence itself is accumulated in
  # another array q.
  local -n __exclude=${2}
  for tag in "${__exclude[@]}"
  do
    not+=( -not -iname "$tag" )
  done
  local -n gen=${1:-fileset_local}
  shift 2
  for arg
  do
    case "$arg" in
    ( "!"*"+"* )
        q+=( -not '(' )
        : "${arg:1}"
        for tag in ${_//+/ }
        do
          [[ $tag == *\** ]] || tag="*$tag*"
          q+=( -ipath "$tag" )
        done
        q+=( ')' )
      ;;
    ( "!"* )
        [[ $arg == *\** ]] && arg=${arg:1} || arg="*${arg:1}*"
        not+=( -not -ipath "$arg" )
      ;;
    ( *"+"* )
        q+=( -o '(' )
        for tag in ${arg//+/ }
        do
          [[ $tag == *\** ]] || tag="*$tag*"
          q+=( -ipath "$tag" )
        done
        q+=( ')' )
      ;;
    ( * )
        [[ $arg == *\** ]] || arg="*$arg*"
        q+=( -o -ipath "$arg" )
      ;;
    esac
  done
  # Close tag match group and append not group
  q+=( ')' )
  q+=( "${not[@]}" )
  ! ((DEBUG)) || {
    ((QUIET)) ||
      >&2 echo "> ${gen[*]} ${q[*]@Q}"
  }
  "${gen[@]}" "${q[@]}"
}

fileset_init ()
{
  local -n __filter=${FILESET_TAG}_${1}
  [[ ${__filter[*]:+set} ]] || fileset_create_filter "$@"
}

# Id: fileset.lib.sh                             vim:set ft=bash sw=2 sts=2 et:
