#!/bin/sh

### .meta: Metadata folder and files

## Organized metadata for files and folders

# While metadata implies structure, this strictly deals with key/values and
# caching values. It does do generic k/v storage for folders and files, but
# it does not for example map metafile keys so that they can be kept in a
# metadir folder.
# XXX: using the term `attributes` for these while `properties`
# (which implies some type/class constraint) is explored in ``status{,dir}.sh``
# and contexts.
# XXX: real caching would be nice, but initially what is meant is syncing with
# xattr.

# XXX: cleanup
# .attributes is a local asis property file, to set metadata for a directory.
# It is used by various scripts to get local configuration settings, and for
# example to override package.yaml project metadata.

# See also metadir.lib. And metainfo.lib for stuff previously here.


meta_lib_load ()
{
  true "${META_DIR:=.meta}"
}

meta_lib_init ()
{
  test -d "$META_DIR"
}


# XXX: cleanup
meta_api_man_1='
  attributes
  emby-list-images [$DKCR_VOL/emby/config]
'


# - Default path argument is PWD.
# - $out_fmt governs the output format:
meta_attribute () # ~ <Key> [ <Path...> ] # Show attribute values for folder or file set
{
  test -e .attributes || return
  test -n "$1" || error meta-attributes-act 1
  case "$1" in
    tagged )
        test -n "$2" || set -- "$1" "src"
        grep $2 .attributes | cut -f 1 -d ' '
      ;;
  esac
}

# - Default path argument is PWD.
# - $out_fmt governs the output format:
#
meta_attributes () # ~ [ <Path...> ] # Show attributes for folder or file set
{
  getfattr -d "$@" 2>/dev/null | tail -n +2
  #xattr -l "$@"
}

# Convert As-is style formatted file to double-quoted variable declarations
meta_attributes_sh () # ~ <File|Awk-argv> # Filter to rewrite .attributes to simple shell variables
{
  awk '{ st = index($0,":") ;
      key = substr($0,0,st-1) ;
      gsub(/[^A-Za-z0-9]/,"_",key) ;
      print toupper(key) "=\"" substr($0,st+2) "\"" }' "$@"
}
# Id: meta-attributes-sh


json_to_csv()
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
