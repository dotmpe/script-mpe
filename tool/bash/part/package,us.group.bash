# .group.bash file, see User-Conf us-part for specification.
#
# Copyright 2008-2026 B. van Berkum <dev@dotmpe.com>
#
# Distributed under terms of the MIT license.
us_package_pre=User-Script.Package
us_package_cnk=0298b2e5
us_package_fun=(
  .assert-id
  .detect-format
  .main-id
  .set-to-local
  .update-part-json
  .update-json
  .write-scripts
)
declare -gA \
us_package_als=(
  [package_assertid]=.assert-id
  [package_detect]=.detect-format
  [package_getjsonpart]=.update-part-json
  [package_mainid]=.main-id
  [package_setlocal]=.set-to-local
  [package_updatejson]=.update-json
  [package_writescripts]=.write-scripts
)

declare -gA \
us_package_hooks=(
  [init]='{
  detect_versions jsotk.py jq
  us_config -n LCACHE_DIR \$METADIR/cache
  us_config -n PACK_DIR \$METADIR/package
  us_config -n PACK_TOOLS \$PACK_DIR/tools
  us_config -n PACK_ENVD \$PACK_DIR/envs
  us_config -n PACK_SCRIPTS \$PACK_DIR/scripts
}'
  [init@local]='{
  us_config -n PACK_SH \$PACK_DIR/\$package_id.sh
  us_config -n PACK_JSON \$PACK_DIR/\$package_id.json
}'
)

User-Script.Package.assert-id ()
{
: param 'Package-Id [Package-Type]'
  [[ -n "${2-}" ]] || set -- "$1" "${package_type:="application/vnd.org.wtwta.project"}"
  jq -r 'map(select(.type=="'"$2"'" and .id=="'"$1"'")) | .[].id' $PACKAGE_JSON
}

User-Script.Package.detect-format ()
{
: about 'Detect package format and set PACKMETA'
: param '~ [Package-Dir] ...'
  local path=${1:-$PWD} ext
  for ext in yml yaml sh
  do
    test -e $path/package.$ext || continue
    package_fmt=$ext
    break
  done
  test -n "${package_fmt-}" || return
  PACKMETA="package.$package_fmt"
}
# Look for package with main attribute
User-Script.Package.main-id ()
{
: param '~ [Package-Type] [Package-JSON]'
  [[ ${1:+set} ]] || set -- "${package_type:-"application/vnd.org.wtwta.project"}"
  # main reference can occur and any object, but must all reference the same
  # id per basedir
  jq -r 'map(select(.type=="'"$1"'" and .main)) | .[].main' $PACKAGE_JSON | tail -n 1
}

User-Script.Package.set-to-local ()
{
: private-prefix package
: param '~ <Package-path> [<Id>] ...'
: input "${1:?Package path}"
  [[ -d "${1}" ]] || failerr "Package basedir location expected" || return
  package_dir="$1"
  package_detect ||
    failerr "E$? looking for package filename" 127 || return

  >&2 mkdir -vp \
    ${LCACHE_DIR} \
    ${PACK_DIR}/{tools,envs,scripts}

  # XXX: Detect wether Pre-process is needed
  grep -q '^#include\ ' "$PACKMETA" && {
    PACKMETA_SRC="$PACKMETA"
    PACKMETA=$LCACHE_DIR/package.$package_fmt
    package_preproc || return
  } || PACKMETA_SRC=''

  PACKAGE_JSON=$LCACHE_DIR/package.json
  [[ -s $PACKAGE_JSON && $PACKMETA -ot $PACKAGE_JSON ]] || {
    package_updatejson || failerr "E$? updating JSON" || return
  }

  # Now check requested Id or get
  if [[ -n "${2-}" && "${2-}" != [.\(]main* ]]
  then
    TODO "XXX: set specific Id from package list yaml"
    package_id=$(package_assertid "$2") || return
  else
    default_package_id=$(package_mainid) || return
    package_id="$default_package_id"
  fi
  [[ ${package_id:+set} ]] || return
  _NOTICE "Set package-Id $package_id"

  symlink_assert $PACK_DIR/main.sh $package_id.sh
  symlink_assert $PACK_DIR/main.json $package_id.json

  PACK_JSON=$PACK_DIR/$package_id.json
  PACK_SH=$PACK_DIR/$package_id.sh
  package_getjsonpart &&
  jsotk.py dump -I json -O fkv "$PACK_JSON" "$PACK_SH" ||
    failerr "E$? dumping shell keys"
}

User-Script.Package.update-part-json ()
{
  local list_json=${1:-$PACKAGE_JSON} part_json=${2:-$PACK_JSON}
  [[ -e $list_json && -s $part_json && $list_json -ot $part_json ]] && return
  _NOTICE "Fetching $part_json from $list_json.."
  jq '
    map(select(.id=="'"$package_id"'" or .main=="'"$package_id"'")) | .[0]
  ' "$list_json" >"$part_json" &&
  [[ -s "$part_json" ]] && grep -qv '^null$' "$part_json" || {
    rm "$part_json"
    failerr "Failed reading package '$package_id' from $list_json ($?)" 1
  }
}

User-Script.Package.update-json ()
{
: param 'FILE SRC'
  [[ $# -gt 0 ]] || set -- "$PACKMETA"
  [[ $# -gt 1 ]] || set -- "$1" "$PACKAGE_JSON"
  [[ $# -eq 2 ]] || return 98

  # XXX:
  case "$1" in
  ( *.sh )            grep '^[^]*=' "$1" | jsotk.py dump -I fkv - "$2" ;;
  ( *.yml | *.yaml )  jsotk.py yaml2json "$1" "$2" ;;
  ( * )               return 99;
  esac
}

User-Script.Package.write-scripts ()
{
  local script{,s,line}
  mapfile -t scripts < <(jq -r '.scripts | keys | .[]' "$PACK_JSON")
  for script in "${scripts[@]}"
  do
    # XXX: evaluate some script from template? probably some other object
    #while read -r scriptline
    #do
    #  . <(echo "echo \"$scriptline\"")
    #done \
    out="$PACK_SCRIPTS/$script.sh"
    [[ -s $out && $out -nt $PACK_JSON ]] ||
      >| "$out" jq -r ".scripts.\"$script\" | if type == \"array\" then .[] else . end" "$PACK_JSON"
  done
}

# Id: package,us         vim:set ft=bash sw=2 sts=2 et:
