#!/bin/sh

### Metadata folder and files (.meta)

## Organized metadata for files and folders


meta_lib__load ()
{
  true "${METADIR:=.meta}" # Relative ref for local meta directory
}

meta_lib__init ()
{
  test -z "${meta_lib_init:-}" || return $_
  test -d "$METADIR" || {
      mkdir -p "$METADIR"
      $LOG warn : "Created local metadir" "$METADIR"
    }
  : "${meta_providers:=fsattr git-annex dotattr aprops}"
  : "${meta_be:=aprops}"
  declare -ga meta=()
}


meta_lib_init_providers () # (us) ~ [ <Providers...> ]
{
  test $# -gt 0 || set -- ${meta_providers:?}
  set -- $(
      for meta_h in "${@:?}"
      do
        meta_be_loaded "${meta_h:?}" || echo "meta-$meta_h"
      done)
  test $# -eq 0 && return
  # Load and init shell libs
  lib_load "$@" && lib_init "$@"
}


# - Default path argument is PWD.
# - $out_fmt governs the output format:
# XXX: see meta-xattr.lib for alt
meta_attribute () # ~ <Key> [ <Path...> ] # Show attribute values for folder or file set
{
  # @Metadir @Extfs
  test -e .attributes || return
  test -n "$1" || error meta-attributes-act 1
  case "$1" in
    tagged )
        test -n "$2" || set -- "$1" "src"
        grep $2 .attributes | cut -f 1 -d ' '
      ;;
  esac
}

# Fetch values or use defaults if provided.
#
# - Default path argument is PWD.
# - $out_fmt governs the output format:
#
meta_attributes () # ~ [ <Path...> ] # Show attributes for folder or file set
{
  getfattr -d "$@" 2>/dev/null | tail -n +2
  #xattr -l "$@"
}

meta_be_loaded () # ~ <Backend-name>
{
  sh_fun meta__${1//[^A-Za-z0-9_]/_}__new
}

meta_cache_proc () # ~ <Src> <Src-key> <Cmd...>
{
  test 3 -le $# || return ${_E_MA:?}
  local src=${1:?} sk=${2:?meta-cache-proc: Source key expected} cached
  shift 2
  cached=${LCACHE_DIR:?}/$sk.out
  test -e "$cached" &&
  test "$src" -ot "$cached" || {
    "$@" >| "$cached"
  }
}

meta_cache_proc_srckey () # ~ <Src-key> <Cmd...>
{
  test 2 -le $# || return ${_E_MA:?}
  local sv=${1:?meta-cache-proc-srckey: Source variable expected} cached
  shift
  meta_cache_proc "${!sv:?}" "$sv" "$@"
}

# Accumulate data from providers and format.
meta_dump () # ~ <Paths...>
{
  local meta_h
  for meta_h in ${meta_providers:-}
  do
    meta_value__${meta_h} "$1"
  done
}

meta_properties () # ~ <Target-file> <Cmd...>
{
  local tf=${1:?} cmd=${2:-}
  shift 2
  case "$cmd" in

    ( assert-tags ) # ~ ~ <Tags...> # Include unique tags with current set
        meta_assert=combine-words \
        meta_properties "$tf" assert-words tags "$@"
      ;;

    ( assert-words ) # ~ ~ <Field> <Words...>
        declare field=${1:?} var
        shift
        meta_new_id
        meta__${meta_be:?}__new "$tf" &&
        meta__${meta_be:?}__loaded && {
          meta_id=$(meta__${meta_be:?}__obj_id "$tf") || return
        } || {
          meta__${meta_be:?}__exists || {
            meta__${meta_be:?}__init "$field" "$*" &&
            meta__${meta_be:?}__commit &&
            $LOG info : "Created" "$meta_path"
            return
          }
          meta__${meta_be:?}__fetch ||
            $LOG error : "Failed to retrieve" "E$?:$meta_id:$meta_ref" $? ||
            return
        }
        var="meta_aprop__${field}[${meta_id:?}]"
        case "${meta_assert:-}" in
          ( combine-words )
              if_ok "$(unique_args ${!var-} "$@")" &&
              <<< "$_" mapfile -t new_args &&
              new_value=${new_args[*]}
            ;;
          ( reset-words )
              if_ok "$(unique_args "$@")" &&
              new_value=${_//$'\n'/ }
            ;;
            * ) return ${_E_nsa:?}
        esac || return
        test "${!var-}" = "$new_value" && {
          $LOG debug : "No change" "$meta_path"
          return
        } || {
          meta__${meta_be:?}__update "$field" "$_" &&
          meta__${meta_be:?}__commit &&
          $LOG info : "Updated" "$meta_path"
          return
        }
      ;;

    ( exists )
        meta__${meta_be:?}__new "$tf" &&
        meta__${meta_be:?}__exists
      ;;

    ( fetch )
        meta__${meta_be:?}__new "$tf"
        meta_new_id
        meta__${meta_be:?}__fetch
      ;;

    ( reset-tags ) # ~ ~ <Tags...> # Set to unique tags from given
        meta_assert=reset-words \
        meta_properties "$tf" assert-words tags "$@"
      ;;

      * ) return ${_E_nsk:?}
  esac
}

meta_new_id ()
{
  meta_id=$RANDOM
  while test "unset" != "${meta[$meta_id]-unset}"
  do meta_id=$RANDOM
  done
}


# --- util

#eval "$(compo declare conv_fields_shell)"
conv_fields_shell ()
{
# Translate uniform fields format into shell variable declarations
  awk '
    match($0, /^([^:]+): (.*)/, a) {
        gsub("[^a-zA-Z0-9_]", "_", a[1])
        gsub("[$\"]", "\\\\&", a[2])
        $0 = a[1]"=\""a[2]"\""
    } 1 '
}
# Copy: INC:conv-fields-shell

json_to_csv () # ~ <Jq-expr> <Fields...>
{
  test -n "$1" || error "JQ selector req" 1 # .path.to.items[]
  local jq_sel="$1" ; shift ;
  test -n "$*" || error "One or more attribute names expected" 1
  trueish "$csv_header" &&
    { echo "$*" | tr ' ' ',' ; } || { echo "# $*" ; }

  local _s="$(echo "$*"|words_to_lines|awk '{print "."$1}'|lines_to_words)"
  jq -r "$jq_sel"' | ['"$(echo $_s|wordsep ',')"'] | @csv'
}

# Id: script-mpe/0.0.4-dev meta.lib.sh
