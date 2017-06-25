#!/bin/sh


# Deal with package metadata files


package_lib_load()
{
  test -n "$1" || set -- .
  PACKMETA="$(cd "$1" && echo package.y*ml | cut -f1 -d' ')"
  test -e "$1/$PACKMETA" && {
    # Default is main
    default_package_id=$(
      jsotk.py -I yaml -O py objectpath $1/$PACKMETA '$.*[@.main is not None].main'
    )
    test -n "$package_id" || {
      package_id="$default_package_id"
      note "Set main '$package_id' from $1/package default"
    }
    test "$package_id" = "$default_package_id" && {
      PACKMETA_BN="$(package_basename)"
    } || {
      PACKMETA_BN="$(package_basename)-${package_id}"
    }
    #PACKMETA_JSON=$1/.$PACKMETA_BN.json
    PACKMETA_JS_MAIN=$1/.$PACKMETA_BN.main.json
    PACKMETA_SH=$1/.$PACKMETA_BN.sh

    export package_id PACKMETA PACKMETA_BN PACKMETA_JS_MAIN PACKMETA_SH
  }
}


package_basename()
{
  test -n "$1" || set -- "$PACKMETA"
  basename "$(basename "$(basename "$1" .json)" .yaml)" .yml
}


update_package_json()
{
  test -n "$1" || set -- ./
  test -n "$metajs" || local metajs=$PACKMETA_JSON
  metajs=$(normalize_relative "$metajs")
  test $metaf -ot $metajs ||
  {
    debug "$metaf is newer than $metajs"
    note "Regenerating $metajs from $metaf.."
    jsotk.py yaml2json $metaf $metajs \
      || return $?
  }
}


jsotk_package_sh_defaults()
{
  {
    jsotk.py -I yaml -O fkv objectpath $1 '$..*[@.*.defaults]' \
      || {
        # TODO: check ret codes warn "Failed reading package defaults from $1 ($?)"
        return 1
      }

  } | sed 's/^\([^=]*\)=/test -n "$\1" || \1=/g'
}


# Easy access for shell to package.yml/json: convert to Sh vars.
update_package_sh()
{
  test -n "$1" -a -d "$1" || error "update-package-sh dir '$1'" 21
  test -n "$metash" || metash=$PACKMETA_SH
  test -n "$metamain" || metamain=$PACKMETA_JS_MAIN
  metash=$(normalize_relative "$metash")
  test $metaf -ot $metash \
    || {

    # Format Sh script/vars from local package
    note "Regenerating $metash from $metaf.."

    # Format Sh default env settings
    { jsotk_package_sh_defaults "$metaf" || {
      test ! -e $metash || rm $metash
    }; } | sort -u > $metash

    test -s "$metash" && {
      grep -q Exception $metash && rm $metash
    } || rm $metash

    # Format main block

    { jsotk.py -I yaml objectpath $metaf '$.*[@.id is "'$package_id'"]' || {
      warn "Failed reading package '$package_id' from $1 ($?)"
      rm $metamain
      return 17
    }; }  > $metamain

    test -s "$metamain" || {
      warn "Failed reading package main from $1 ($package_id)"
      rm $metamain
      return 16
    }

    jsotk.py --output-prefix=package to-flat-kv $metamain | sort -u >> $metash || {
      warn "Failed writing package Sh from $1 ($?)"
      rm $metash
      return 15
    }
  }
}


package_file()
{
  test -n "$metaf" || metaf="$(echo $1/package.y*ml | cut -f1 -d' ')"
  metaf=$(normalize_relative "$metaf")
  test -e "$metaf" || return 1
}


# Allow for a sole .package.sh file to be used iso. full package.yml
# In this case create a YAML elsewhere
update_temp_package()
{
  return 1
  test -n "$pdoc" || error pdoc 21
  test -n "$ppwd" || ppwd=$(cd $1 && pwd)

  mkvid "$ppwd"
  metaf=$(setup_tmpf .yml "-meta-$vid")
  test -e $metaf || touch $metaf $pdoc
  #test -e "$metaf" && return || {
    metash=$1/$metaf_SH
    test -e $metaf -a $metaf -nt $pdoc || {
      pd__meta package $1 > $metaf
    }
  #}
  export PACKMETA=$metaf
}


# Given package.yaml metafile, extract and fromat as SH, JSON. If no local
# package.yaml exists, try to extract one temp package YAML from Pdoc.
update_package()
{
  test -n "$1" -a -d "$1" || error "update-package dir '$1'" 21
  test -z "$2" || error "update-package surplus args '$2'" 22

  local metaf= metash= metamain=
  test -n "$ppwd" || ppwd=$(cd $1; pwd)

  package_file "$1" || {
    update_temp_package "$1" || { r=$?
      rm $metaf
      error update_temp_package-$r
      return 23
    }
  }
  test -e "$1/$PACKMETA" || error "no such file ($(pwd)) PACKMETA='$PACKMETA'" 34

  # Package.sh is used by other scripts
  update_package_sh "$1" || {
    r=$?
    grep -q Exception $metash && rm $metash
    return $r
  }

  # .package.json is not used, its a direct convert of te entire YAML doc.
  # Other scripts can use it with jq if required
  update_package_json "$1" || return $?
}


# Given local .package.sh exists, see about and export some requested key-values.
# map=[ PREF[:SUB ] ] package-sh KEYS
# The env 'map' is a mapping consisting of the prefix to match and strip,
# with an optional subtitution key for the prefix. The rest of the arguments
# are the keys which are passed through as value declarations on stdout.
# Non-existant keys or empty values are passed over silently.
package_sh()
{
  test -n "$1" || error "package-sh keys expected" 1
  # Set or use mapping from env
  test -n "$map" || map=package_
  fnmatch "*:*" "$map" && {
    prefix="$(printf "$map" | cut -d ':' -f 1)"
    sub="$(printf "$map" | cut -d ':' -f 2)"
  } || {
    prefix="$map"
    sub=
  }
  # Check/update package metadata
  test -e $PACKMETA && {
    update_package $(pwd -P) || return $?
  }
  test -e $PACKMETA_SH || error $PACKMETA_SH 1
  # Use util from str.lib to get the keys from the properties file
  property "$PACKMETA_SH" "$prefix" "$sub" "$@"
}


package_get_key() # Dir Package-Id Property
{
  test -d "$1" || error "dir expected" 1
  local dir="$1" package_id="$2"
  shift 2
  cd "$dir"
  # Check/update package metadata
  test -e $PACKMETA && {
    update_package $(pwd -P) || return $?
  }
  while test $# -gt 0
  do
    echo jsotk.py objectpath $PACKMETA '$.*[@.id is "'$package_id'"].'$1
    shift
  done
}


package_default_env()
{
  set --
}


package_sh_env()
{
  set --
}


# XXX: iso. using .package.sh read lines from JSON
# package-sh-script SCRIPTNAME [JSOTKFILE]
package_sh_script()
{
  test -n "$2" || set -- "$1" $PACKMETA_JS_MAIN
  test -e "$2"
  jsotk.py path -O lines "$2" scripts/$1 || {

    error "error getting lines for '$1'"
    return 1
  }
}


# package-sh-list PACKAGE-SH LIST-KEY
package_sh_list()
{
  test -n "$1" || set -- $PACKMETA_SH
  test -n "$2" || error package_sh_list:list-key 1
  test -n "$show_index" || show_index=0
  test -n "$show_item" || show_item=1
  read_nix_style_file $1 | grep '^package_'"$2" |
    sed 's/^package_'"$2"'__\([0-9]*\)/\1/g' |
    while IFS='=' read index item
    do
      echo \
        $(trueish "$show_index" && echo $index) \
        $(trueish "$show_item" && echo $item)
    done
}


package_sh_list_exists()
{
  test -n "$(eval echo "\$package_${1}__0")"
}


# Id: script-mpe/0.0.4-dev package.lib.sh
