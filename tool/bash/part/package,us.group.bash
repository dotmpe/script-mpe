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
  .update-json
)
declare -gA \
us_package_als=(
  [package_detect]=.detect-format
  [package_assertid]=.assert-id
  [package_mainid]=.main-id
  [package_setlocal]=.set-to-local
  [package_updatejson]=.update-json
)
declare -gA \
us_package_ssc=(
)
declare -gA \
us_package_hooks=(
  [init]='{
  detect_versions jsotk.py jq
  : "${LCACHE_DIR:=$METADIR/cache}"
  : "${PACK_DIR:=$METADIR/package}"

  : "${PACK_TOOLS:=$PACK_DIR/tools}"
  : "${PACK_ENVD:=$PACK_DIR/envs}"
  : "${PACK_SCRIPTS:=$PACK_DIR/scripts}"
}'
)

User-Script.Package.assert-id ()
{
: param 'Package-Id [Package-Type]'
  test -n "${2-}" || set -- "$1" "${package_type:="application/vnd.org.wtwta.project"}"
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

  # Detect wether Pre-process is needed
  grep -q '^#include\ ' "$PACKMETA" && {
    PACKMETA_SRC="$PACKMETA"
    PACKMETA=$METADIR/cache/package.$package_fmt
    package_preproc || return
  } || PACKMETA_SRC=''

  PACKAGE_JSON=$METADIR/cache/package.json
  [[ -s $PACKAGE_JSON && $PACKMETA -ot $PACKAGE_JSON ]] || {

    package_updatejson || return
  }

  if [[ -n "${2-}" && "${2-}" != [.\(]main* ]]
  then
    package_id=$(package_assertid "$2") || return
  else
    default_package_id=$(package_mainid) || return
    package_id="$default_package_id"
    symlink_assert $PACK_DIR/main.sh $package_id.sh
    symlink_assert $PACK_DIR/main.json $package_id.json
  fi
  [[ ${package_id:+set} ]] || return
  NOTICE "Set package-Id $package_id"

  PACK_JSON=$PACK_DIR/$package_id.json
  PACK_SH=$PACK_DIR/$package_id.sh
}

User-Script.Package.update-json () # FILE SRC
{
  test $# -gt 0 || set -- "$PACKMETA"
  test $# -gt 1 || set -- "$1" "$PACKAGE_JSON"
  test $# -eq 2 || return 98

  case "$1" in
      *.sh ) grep '^[^]*=' "$1" | jsotk.py dump -I fkv - "$2" || return ;; # FIXME: jsotk.py dump -I fkv
      *.yml | *.yaml ) jsotk.py yaml2json "$1" "$2" || return ;;
      * ) return 99;
  esac
}

# Id: package,us         vim:set ft=bash sw=2 sts=2 et:
