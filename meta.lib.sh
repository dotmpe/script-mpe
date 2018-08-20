#!/bin/sh


meta_lib_load()
{
  test -n "$emby_vol" || emby_vol=$DCKR_VOL/emby
  test -n "$emby_conf" || emby_conf=$DCKR_VOL/emby/config
  fnmatch "*/" "$emby_conf" &&  error "$emby_conf trailing /" 1 || true
}

# Return mime-type (from BSD/GNU file) on Linux and Darwin
file_mime()
{
  test -e "$1" || error "expected existing path <$1>" 1
  case "$uname" in

    Darwin ) file -b --mime-type "$1" ;;
    Linux ) file -bi "$1" ;;

    * ) error "No file MIME-type on $uname" 1 ;;

  esac
}


mediadurationms()
{
  echo "General;%Duration%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediaresolution()
{
  echo "Video;%Width%x%Height%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediapixelaspectratio()
{
  echo "Video;%PixelAspectRatio/String%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediadisplayaspectratio()
{
  echo "Video;%DisplayAspectRatio/String%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}


# General;%CompleteNae% * %FileSize/String3% * %Duration/String%
# Video; |Video: %Width%x%Height% * %DisplayAspectRatio/String% * %Format%
# %Format_Profile%
# Audio; |Audio: %Language/String% * %Channel(s)% CH * %Codec/String%
# Text; |Sub: %Language/String% * %Codec%
# File_End;\n

meta_api_man_1='
  attributes
  emby-list-images [$DKCR_VOL/emby/config]
'

meta_attribute()
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


emby_api_init()
{
  test -n "$emby_api" || emby_api=http://localhost:8096
  test -n "$emby_api_key" || error "Emby API key required" 1
  test -n "$emby_user" || error "Emby API user required" 1

  _emby_auth_fmt="$emby_api/emby/%s&api_key=${emby_api_key}"

  mkdir -p .emby
  _emby_itjs=.emby/items
  _emby_roots=.emby/roots
}

emby_api_man_1='
  item-roots
  items-sub
  items
  items-by-id
  item-images
    Tabulate images
'

emby_api__items() # [Fields]
{
  test -n  "$*" ||
set -- Id Name ServerId Container RunTimeTicks IsFolder Type LocationType MediaType
  fields=$(echo "$*" | tr ' ' ',')
  curl -sSf -X GET "$(printf -- "$_emby_auth_fmt" "/Items?fields=${fields}")" \
    -H "accept: application/json"
}

# Output CSV, set csv_header=1 to get columnnames-line
emby_api__item_roots()
{
  set -- Id ServerId IsFolder Type LocationType Name
  test -e "$_emby_roots.json" || {
    emby_api__items "$@" > "$_emby_roots.json"
  }
  test "$_emby_roots.tab" -nt "$_emby_roots.json" || {
    json_to_csv '.Items[]' "$@" \
      < "$_emby_roots.json" \
      > "$_emby_roots.tab"
  }
  cat "$_emby_roots.tab"
}

emby_api__items_sub() # Parent-Id [Fields]
{
  test -n "$1" || error "Parent-Id required" 1 ; local p_id="$1" ; shift
  test -n  "$*" ||
set -- Id Name ServerId Container RunTimeTicks IsFolder Type LocationType MediaType
  fields=$(echo "$*" | tr ' ' ',')
  curl -sSf -X GET "$(printf -- "$_emby_auth_fmt" \
      "/Items?parentid=$p_id&fields=${fields}")" \
       -H "accept: application/json"
}

# Output CSV, set csv_header=1 to get columnnames-line
emby_api__items()
{
  set -- Id ServerId IsFolder Type LocationType Name
  while read parent_id
  do
    note "Looking for sub-items in ${parent_id}"

    test -e "$_emby_itjs${parent_id}.json" || {
      emby_api__items_sub "$parent_id" "$@" > "$_emby_itjs${parent_id}.json"
    }
    test "$_emby_itjs${parent_id}.tab" -nt "$_emby_itjs${parent_id}.json" || {
      json_to_csv '.Items[]' "$@" \
        < "$_emby_itjs${parent_id}.json" \
        > "$_emby_itjs${parent_id}.tab"
    }
    cat "$_emby_itjs${parent_id}.tab"
  done
}

emby_api__items_by_id()
{
  ids=$(echo "$@" | tr ' ' ',')
  curl -sSf -X GET "$(printf -- "$_emby_auth_fmt" "/Items?ids=${ids}")" \
    -H "accept: application/json"
}

# Use filesytem to list item ID's with some local JPG associated
meta_emby_list_images()
{
  local depth=$(echo "$emby_conf" | awk -F"/" '{print NF-1}')
  find $emby_conf/metadata/library -iname '*.jpg' |
      cut -d'/' -f$(( ${depth} + 5 )) |
      sort -u
}

# Tabulate items with image names?
emby_api__item_images()
{
  #meta_emby_list_images | p= s= act=emby_api__items_by_id foreach_do
  meta_emby_list_images | while read item_id
  do
    emby_api__items_by_id $item_id | jq -r '.Items[] | "\(.Id) \(.Name)"'
  done
}


# Id: script-mpe/0.0.4-dev meta.lib.sh
