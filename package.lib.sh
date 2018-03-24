#!/bin/sh


# Deal with package metadata files


package_lib_load()
{
  test -n "$1" || set -- .
  # Get first existing file
  PACKMETA="$(echo "$1"/package.y*ml | cut -f1 -d' ')"
  upper=0 default_env out-fmt py || true
}

package_lib_set_local()
{
  test -n "$1" || error "package.lib load" 1
  # Default is main
  default_package_id=$(package_default_id "$1")
  test -n "$package_id" -a "$package_id" != "(main)" || {
    package_id="$default_package_id"
    note "Set main '$package_id' from $1/package default"
  }
  test "$package_id" = "$default_package_id" && {
    PACKMETA_BN="$(package_basename)"
  } || {
    PACKMETA_BN="$(package_basename)-${package_id}"
  }
  PACKMETA_JSON=$1/.$PACKMETA_BN.json
  PACKMETA_JS_MAIN=$1/.$PACKMETA_BN.main.json
  PACKMETA_SH=$1/.$PACKMETA_BN.sh

  export package_id PACKMETA PACKMETA_BN PACKMETA_JS_MAIN PACKMETA_SH
}

package_default_id()
{
  test -e "$1/$PACKMETA" || error "package-default-id no file '$1/$PACKMETA'" 1
  jsotk.py -I yaml -O py objectpath $1/$PACKMETA '$.*[@.main is not None].main'
}

package_file()
{
  test -n "$metaf" || metaf="$(echo $1/package.y*ml | cut -f1 -d' ')"
  metaf=$(normalize_relative "$metaf")
  test -e "$metaf" || return 1
}


htd_package_list_ids()
{
  test -e "$PACKMETA" || error "htd-package-list-ids no file '$PACKMETA'" 1
  jsotk.py -I yaml -O py objectpath $PACKMETA '$.*[@.id is not None].id'
}


package_basename()
{
  test -n "$1" || set -- "$PACKMETA"
  basename "./$(basename "./$(basename "$1" .json)" .yaml)" .yml
}


update_package_json()
{
  test -n "$1" || set -- ./
  test -n "$metajs" || local metajs=$PACKMETA_JSON
  test -e "$metaf" || error "update-package-json no metaf '$metaf'" 1
  metajs=$(normalize_relative "$metajs")
  test $metaf -ot $metajs ||
  {
    stderr debug "$metaf is newer than $metajs"
    note "Regenerating $metajs from $metaf.."
    jsotk.py yaml2json $metaf $metajs \
      || return $?
  }
}


jsotk_package_sh_defaults()
{
  test -e "$1" || error "jsotk-package-sh-defaults no file '$1'" 1
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

  test ! -e "$metash" -o -f "$metash" || {
    error "metash file: $metash"
    return 1
  }
  test $metaf -ot $metash || {

    # Format Sh script/vars from local package
    note "Regenerating $metash from $metaf.."

    # Format Sh default env settings
    { jsotk_package_sh_defaults "$metaf" || {
      test ! -e $metash || rm $metash
    }; } | sort -u > $metash

    test -s "$metash" && {
      grep -q Exception $metash && rm $metash
    } || {
      test -z "$metash" -o ! -e "$metash" || rm $metash
    }

    # Format main block

    { jsotk.py -I yaml objectpath $metaf '$.*[@.id is "'$package_id'"]' || {
      warn "Failed reading package '$package_id' from $1 ($?)"
      test -z "$metamain" -o ! -e "$metamain" ||
        rm $metamain
      return 17
    }; }  > $metamain

    test -s "$metamain" || {
      warn "Failed reading package main from $1 ($package_id)"
      test -z "$metamain" -o ! -e "$metamain" ||
        rm $metamain
      return 16
    }

    jsotk.py --output-prefix=package to-flat-kv $metamain | sort -u >> $metash || {
      warn "Failed writing package Sh from $1 ($?)"
      test -z "$metash" -o ! -e "$metash" ||
        rm $metash
      return 15
    }
  }
}


# Allow for a sole .package.sh file to be used iso. full package.yml
# In this case create a YAML elsewhere
update_temp_package()
{
  test -n "$pdoc" || error pdoc 21
  test -n "$ppwd" || ppwd=$(cd $1 && pwd)

  mkvid "$ppwd"
  metaf=$(setup_tmpf .yml "-meta-$vid")
  test -e $metaf || touch $metaf $pdoc

  metash=$(pathname "$metaf" .yml .yaml).sh
  fnmatch "$TMPDIR/*" "$metash" || metash=$(dotname "$metash")
  metajs=$(pathname "$metaf" .yml .yaml).js
  fnmatch "$TMPDIR/*" "$metajs" || metajs=$(dotname "$metajs")
  metamain=$(pathname "$metaf" .yml .yaml).main
  fnmatch "$TMPDIR/*" "$metamain" || metamain=$(dotname "$metamain")

  test -e $metaf -a $metaf -nt $pdoc || {
    pd__meta package $1 > $metaf
  }
  export PACKMETA=$metaf
}


# Given package.yaml metafile, extract and fromat as SH, JSON. If no local
# package.yaml exists, try to extract one temp package YAML from Pdoc.
update_package()
{
  test -n "$1" -a -d "$1" || error "update-package dir '$1'" 21
  test -z "$2" || error "update-package surplus args '$2'" 22

  metaf=
  local metash= metamain=
  test -n "$ppwd" || ppwd=$(cd $1; pwd)

  package_file "$1" || {
    info "Creating temp package since none exists at '$metaf'"
    update_temp_package "$1" || { r=$?
      test -z "$metaf" -o ! -e "$metaf" || rm $metaf
      error "update-temp-package: no '$metaf' for '$1'"
      return 23
    }
  }
  test -e "$metaf" || error "no such file ($(pwd), $1) PACKMETA='$PACKMETA'" 34
  package_lib_set_local "$1"

  info "Metafile: $metaf ($(pwd))"

  # Package.sh is used by other scripts
  update_package_sh "$1" || { r=$?
    test -f "$metash" || return $r
    grep -q Exception $metash && rm $metash ; return $r
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
  test -e "$PACKMETA" && {
    update_package $(pwd -P) || return $?
  }
  test -n "$PACKMETA_SH" -a -e "$PACKMETA_SH" || error "package-sh '$PACKMETA_SH'" 1
  # Use util from str.lib to get the keys from the properties file
  property "$PACKMETA_SH" "$prefix" "$sub" "$@"
}


# Use ObjectPath to get values
# NOTE: double-quote elements with special chars: my.path."with special".element
package_get_keys() # Property...
{
  test -n "$out_fmt" || out_fmt=py
  while test $# -gt 0
  do
    jsotk.py objectpath -O${out_fmt} $PACKMETA '$.*[@.id is "'$package_id'"].'$1
    shift
  done
}

package_dir_get_keys() # Dir Package-Id [Property...]
{
  test -d "$1" || error "dir expected" 1
  local dir="$1" package_id="$2" ; shift 2
  cd "$dir"
  {
    package_lib_set_local "$dir"
    # Check/update package metadata
    test -e $PACKMETA && {
      update_package $(pwd -P) || return $?
    }
    package_get_keys "$@"
  }
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
  test -n "$1" || set -- $PACKMETA_SH "$2"
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
  test -n "$1" || set -- $PACKMETA_SH "$2"
  test -n "$2" || set -- $1 "scripts"
  test -n "$(eval echo "\$package_${2}__0")"
}


htd_package_update()
{
  test -n "$1" || set -- "$(pwd)"
  package_lib_set_local "$1" && update_package $1
}


htd_package_debug()
{
  #test -z "$1" || export package_id=$1
  package_lib_set_local "$(pwd -P)"
  test -n "$1" && {
    # Turn args into var-ids
    _p_extra() { for k in $@; do mkvid "$k"; printf -- "$vid "; done; }
    _p_lookup() {
      . $PACKMETA_SH
      # See if lists are requested, and defer
      for k in $@; do
        package_sh_list_exists "" "$k" || continue
        package_sh_list "" $k
        shift
      done
      test -z "$*" ||
        map=package_ package_sh "$@"
    }
    echo "$(_p_lookup $(_p_extra "$@"))"

  } || {
    read_nix_style_file $PACKMETA_SH | while IFS='=' read key value
    do
      eval $LOG header2 "$(kvsep=' ' pretty_print_var "$key" "$value")"
    done
  }
}

htd_package_urls()
{
  package_lib_set_local "$(pwd -P)"
  test -e "$PACKMETA_JS_MAIN" || error "No '$PACKMETA_JS_MAIN' file" 1
  jsotk.py path -O pkv "$PACKMETA_JS_MAIN" urls
}

htd_package_open_url()
{
  test -n "$1" || error "name expected" 1
  package_lib_set_local "$(pwd -P)"
  . $PACKMETA_SH
  url=$( upper=0 mkvid "$1" && eval echo \$package_urls_$vid )
  test -n "$url" || error "no url for name '$1'" 1
  note "Opening '$1': <$url>"
  open "$url"
}

# Take PACKMETA file and read main package's 'repositories', looking for a local
# remote repository or adding/updating each name/URL.
htd_package_remotes_init()
{
  package_lib_set_local "$(pwd -P)"

  test -e "$PACKMETA_JS_MAIN" || error "No '$PACKMETA_JS_MAIN' file" 1
  vc_getscm
  jsotk.py path -O pkv "$PACKMETA_JS_MAIN" repositories |
      tr '=' ' ' | while read remote url
  do
    # Get rid of quotes
    eval remote=$remote url=$url

    test -n "$remote" -a -n "$url" || {
      warn "empty package repo var '$remote $url'"; continue; }
    # NOTE: multitype repo projects? determine type per suffix..
    fnmatch "*.$scm" "$url" || continue

    note "scm: $scm; remote: '$remote' url: '$url'"
    htd_repository_url "$remote" "$url" || continue
    note "remote: '$remote' url: '$url'"
    vc_git_update_remote "$remote" "$url"
  done
}

# Id: script-mpe/0.0.4-dev package.lib.sh
