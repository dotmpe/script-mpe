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
  # XXX: meta is both provider and backup, others are sources?
  # dotattributes-map is easier to use than to set every source per dir into
  # env manually
  # XXX: fsattr is alt. for xattr?
  : "${meta_providers:=xattr git-annex dotattr}"
}


# XXX: cleanup
meta_api_man_1='
  attributes
  emby-list-images [$DKCR_VOL/emby/config]
'

meta_lib_init_providers () # (us) ~ [ <Providers...> ]
{
  test $# -gt 0 || set -- ${meta_providers:?}
  set -- $(
      for meta_h in "${@:?}"
      do
        sh_fun meta_dump__${meta_h//[^A-Za-z0-9_]/_} || echo "meta-$meta_h"
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

# Accumulate data from providers and format.
meta_dump () # ~ <Paths...>
{
  local meta_h
  for meta_h in ${meta_providers:-}
  do
    meta_value__${meta_h} "$1"
  done
}

# --- util

#eval "$(compo typeset conv_fields_shell)"
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
