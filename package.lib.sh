#!/bin/sh

# Deal with package metadata files


package_lib_load() # (env PACKMETA) [env out_fmt=py]
{
  lib_assert sys os src || return

  test -n "${1-}" || set -- .
  #upper=0 default_env out-fmt py || true
  test -n "${PACK_DIR-}" || PACK_DIR=.htd
  test -d "$1"/$PACK_DIR || mkdir "$1"/$PACK_DIR
  test -n "${PACK_TOOLS-}" || PACK_TOOLS=$PACK_DIR/tools
  test -n "${PACK_SCRIPTS-}" || PACK_SCRIPTS=$PACK_DIR/scripts
  # Get first existing file
  PACKMETA="$(echo "$1"/package.y*ml | cut -f1 -d' ')"
  # Detect wether Pre-process is needed
  {
    test -e "$PACKMETA" && grep -q '^#include\ ' "$PACKMETA"
  } && {
    PACKMETA_SRC=$PACKMETA
    PACKMETA="$1"/$PACK_DIR/package.yaml
  } || PACKMETA_SRC=''

  # XXX: Python path for local lib, & pyvenv
  export PYTHONPATH=${PYTHONPATH-"$PYTHONPATH:"}$HOME/.local/lib/usr-py
  #. ~/.pyvenv/htd/bin/activate
  #preprocess_package || true
}

package_lib_init()
{
  test "${package_lib_init-}" = "0" && return
#
#  test -z "$package_id" -a  \
#      -z "$package_main" || warn "Already initialized ($package_id/$package_main)"
#  package_init_env && package_req_env || warn "Default package env"
  true
}

# Preprocess YAML
preprocess_package()
{
  test -e "$PACKMETA" -a -z "$PACKMETA_SRC" || {
    test -e "$PACKMETA_SRC" || return
    test -e "$PACKMETA" -a "$PACKMETA" -nt "$PACKMETA_SRC" || {
      add_sentinels=1 expand_include_sentinels "$PACKMETA_SRC" > "$PACKMETA"
    }
  }
}

package_lib_reset()
{
  default_package_id=
  default_package_shell=/bin/sh
  # :!grep -ho '\$package_[a-zA-Z0-9_]*' *.sh|sort -u|cut -c2-
  # XXX: rename
  package_build_unit_spec=
  package_specs_units=
  #
  package_components=
  package_cwd=
  package_default=
  package_description=
  package_doc_find=
  package_docs_find=
  package_env=
  package_ext_make_files=
  #package_id=
  package_lib_loaded=
  package_lists_contexts_std=
  package_log=
  package_log_dir=
  package_log_doctitle_fmt=
  package_main=
  package_paths=
  package_pd_meta_checks=
  package_pd_meta_tests=
  package_pd_meta_git_hooks_pre_commit_script=
  package_pd_meta_stats=
  package_pd_meta_tasks_document=
  package_pd_meta_tasks_done=
  package_repo=
  package_shell=
  package_type=
  package_vendor=
  package_version=
  package_check_method=
  package_build_method=
  package_test_method=
  package_permalog_method=
}

package_lib_set_local()
{
  test -n "$1" || error "package.lib set-local" 1
  test -z "$default_package_id" || package_lib_reset
  # Default package is entry named as main
  default_package_id=$(package_default_id "$1") || return
  test -n "$package_id" -a "$package_id" != "(main)" || {
    package_id="$default_package_id"
    std_info "Set main '$package_id' from $1/package default"
  }
  test "$package_id" = "$default_package_id" && {
    PACKMETA_BN="$(package_basename)"
  } || {
    PACKMETA_BN="$(package_basename)-${package_id}"
  }
  $LOG info "" "Set PackMeta-Bn to" "$PACKMETA_BN"
  PACKMETA_JSON=$1/$PACK_DIR/$PACKMETA_BN.json
  PACKMETA_JS_MAIN=$1/$PACK_DIR/$PACKMETA_BN.main.json
  PACKMETA_SH=$1/$PACK_DIR/$PACKMETA_BN.sh

  package_defaults || return
  test -z "$tasks_lib_loaded" && return
  tasks_package_defaults
}

package_defaults()
{
  test -n "${package_main-}" || package_main="$package_id"
  test -n "${package_env_file-}" || package_env_file=$PACK_TOOLS/env.sh
  test -n "${package_log_dir-}" -o -n "$package_log" || package_log="$package_log_dir"

  test -n "${package_components-}" || package_components=package_components
  test -n "${package_component_name-}" || package_component_name=package_component_name

  test -n "${package_permalog_path-}" || package_permalog_path=cabinet
  test -n "${package_permalog_method-}" || package_permalog_method=archive
  test -n "${package_pd_meta_checks-}" || package_pd_meta_checks=
  test -n "${package_check_method-}" || package_check_method=
  test -n "${package_pd_meta_tests-}" || package_pd_meta_tests=
  test -n "${package_pd_meta_targets-}" || package_pd_meta_targets=
}

package_default_id()
{
  test -e "$1/$PACKMETA" || error "package-default-id no file '$1/$PACKMETA'" 1
  jsotk.py -I yaml -O py objectpath $1/$PACKMETA '$.*[@.main is not None].main'
}


package_file()
{
  test -n "${metaf-}" || metaf="$(echo $1/package.y*ml | cut -f1 -d' ')"
  test -e "$metaf" || error "No package-file at '$1' '$metaf'" 1
  metaf="$(normalize_relative "$metaf")"

  grep -q '^#include\ ' "$metaf" && {
    metaf_src="$metaf"
    metaf="$1"/.htd/package.yaml
  } || metaf_src=''
  test -e "$metaf" -a -z "$metaf_src" || {
    test -e "$metaf_src" || return
    mkdir -p "$(dirname "$metaf")"
    test -e "$metaf" -a "$metaf" -nt "$metaf_src" || {
      add_sentinels=1 expand_include_sentinels "$metaf_src" > "$metaf"
    }
  }
  test -e "$metaf" || return 1
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

# Setup eithr local or default package env.
package_init_env()
{
  test -n "${PACKMETA_SH-}" || {
    note "Setting package lib env"
    package_lib_set_local . || {

        warn "No local package config set"
        package_lib_reset && package_defaults
        return 1
    }
  }
}

# Require sh package env.
package_req_env()
{
  test -n "${PACKMETA_SH-}" || return
  note "Loading package lib env"
  test -e "$PACKMETA_SH" || return
  . "$PACKMETA_SH" || return
  package_defaults
}

# Easy access for shell to package.yml/json: convert to Sh vars.
update_package_sh() # CWD
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

    test -n "$package_shell" || package_shell="$default_package_shell"
    { echo "#!$package_shell" ; { jsotk_package_sh_defaults "$metaf" || {
      test ! -e $metash || rm $metash
    }; } | sort -u ; } > $metash

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

    { { echo "#!$package_shell";
      jsotk.py --output-prefix=package to-flat-kv $metamain | sort -u
    } >> "$metash" ; } || {
      warn "Failed writing package Sh from $1 ($?)"
      test -z "$metash" -o ! -e "$metash" ||
        rm "$metash"
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
  PACKMETA=$metaf
}


# Given package.yaml metafile, extract and fromat as SH, JSON. If no local
# package.yaml exists, try to extract one temp package YAML from Pdoc.
update_package() # Dir
{
  test -n "${1-}" -a -d "${1-}" || error "update-package dir '$1'" 21
  test $# -eq 1 || error "update-package surplus args '$2'" 22

  metaf=
  local metash= metamain=
  test -n "${ppwd-}" || ppwd=$(cd $1; pwd)

  package_file "$1" || {
    std_info "Creating temp package since none exists at '$metaf'"
    update_temp_package "$1" || { r=$?
      test -z "$metaf" -o ! -e "$metaf" || rm $metaf
      error "update-temp-package: no '$metaf' for '$1'"
      return 23
    }
  }
  test -e "$metaf" || error "no such file ($(pwd), $1) PACKMETA='$PACKMETA'" 34
  package_lib_set_local "$1"

  std_info "Metafile: $metaf ($(pwd))"

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
  test -n "${PACKMETA_SH-}" -a -e "${PACKMETA_SH-}" ||
      error "package-sh '$PACKMETA_SH'" 1
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


# TODO get or set
package_default_env()
{
  set --
}


# Example/CLI getting from env
package_sh_get_env() # Name V-Id
{
  test -n "$1" || error "Path/key name expected" 1
  test -n "$2" || set -- "$1" "$(upper=0 mkvid "$1" ; echo "$vid")"
  eval echo "\$package_${2}"
}

# Read from package.sh
package_sh_get() # PACKAGE-SH NAME-KEY
{
  test -n "$1" || set -- $PACKMETA_SH "$2"
  # XXX: eval modes anyway, for certain interpolations?
  grep '^package_'"$2"'=' "$1" |
    sed -E 's/^[^=]*=(['\''"](.*)['\''"]$|(.*))$/\2\3/g' | sed 's/\\"/"/g'
}

# List shell profile scriptline(s), to initialize shell env with for 'scripts'
# and other project tasks (sh routines, make, cron, CI/CD, etc.)
package_sh_env()
{
  test -n "${PACKMETA_SH-}" || package_lib_set_local . || return
  test -n "$package_shell" || package_shell="$default_package_shell"
  echo "#!$package_shell"
  test -n "$package_env" && {
    # Single line script
    echo "$package_env"
  } || {
    # Multiline-script
    package_sh_list "$PACKMETA_SH" "env"
  }
}

# Compile env-init scriptlines to executable script
package_sh_env_script() # [Path]
{
  local script_out=
  test -n "${1-}" && script_out="$1" || script_out="$package_env_file"
  test -n "${PACKMETA_SH-}" || package_lib_set_local . || return
  test -s $script_out -a $script_out -nt $PACKMETA && {
    std_info "Newest version of Env-Script $script_out exists"
  } || {
    mkdir -vp "$(dirname "$script_out")" &&
    . "$PACKMETA_SH" &&
    package_sh_env > "$script_out" &&
    note "Updated Env-Script $script_out"
  }
}


# iso. using .package.sh read scriptlines from JSON variant
# package-sh-script SCRIPTNAME [JSOTKFILE]
package_js_script()
{
  test -n "${PACKMETA_SH-}" || package_lib_set_local "$(pwd -P)" || return
  test -n "$2" || set -- "$1" $PACKMETA_JS_MAIN
  test -e "$2"
  jsotk.py path -O lines "$2" scripts/$1 || {

    error "error getting lines for '$1'"
    return 1
  }
}


# Read from package.sh, no env required. But source env if using show-eval(on)
package_sh_list() # show_index=0 show_item=1 show_eval=1 PACKAGE-SH LIST-KEY
{

  test -n "${1-}" || {
    test -n "${PACKMETA_SH-}" || return
    set -- $PACKMETA_SH "${2-}" "${3-}" "${4-}"
  }
  test -n "${2-}" || error package_sh_list:list-key 1
  test -n "${4-}" || set -- "$1" "$2" "${3-}" "package_"
  test -n "$show_index" || show_index=0
  test -n "$show_item" || show_item=1
  test -n "$show_eval" || show_eval=1
  trueish "$show_eval" && {
      test -n "$package_main" || . $1
    }
  local subp="$3" ; test -n "$subp" && subp="__$subp" || subp=''

  grep '^'"$4$2__[0-9]*$subp=" "$1" |
    sed -E 's/^'"$4$2"'__([0-9]+)'"$subp"'=(['\''"](.*)['\''"]$|(.*))$/\1 \3\4/g' |
    while read -r index item
    do
      echo \
        $(trueish "$show_index" && echo "$index") \
        "$( trueish "$show_item" && { \
                trueish "$show_eval" && \
                { eval echo $item ; } || \
                { echo "$item" | sed 's/\\"/"/g' ; } ; \
            } )"
    done
}


# NOTE: scripts must be lists or this doesn't go.
package_sh_list_exists()
{
  test -n "$(eval echo "\$package_${1}__0")"
}

package_sh_name_exists()
{
  test -n "$(eval echo "\$package_${1}")"
}

package_sh_list_or_name_exists()
{
  package_sh_list_exists "$1" || package_sh_name_exists "$1"
}

package_component_name()
{
  test -n "$1" || error package-component-name 1
  filename_baseid "$1"
  echo "$id" | gsed -E '
    s/-((spec)|(lib))//g
    s/-[0-9]+$//g
  '
}

package_paths_io()
{
  local spwd=.

  test "$stdio_0_type" = "t" -o \( -n "$1" -a "$1" != "-" \) && {

# ... retrieve using defined script or vc-tracked to fetch paths
    test -n "$package_paths" || package_paths=vc_tracked
    #eval $package_env || return $?
    $package_paths "$@" || return
  } || cat -
}

# Use package's paths script, or vc-tracked, to retrieve component names and
# locations. This loads all lines to do a group on the first word and takes
# significant time, but should complete without a minute for a large project
package_components()
{
# Grok either given paths on stdin, or...
  package_paths_io "$@" | while read -r name

# Then Id by basename, and use join-lines to group common paths at that prefix
    do
      compid="$($package_component_name "$name")"
      echo "$compid $name"

# Remove hidden files lazily, then group paths after first word
    done | grep -v '^[_-]' | join_lines - ' '
}

package_component_roots()
{
# Grok either given paths on stdin, or...
  package_paths_io "$@" | while read -r name

# Then Id by basename, and use join-lines to group common paths at that prefix
    do
      fnmatch "*/*" "$name" && name="$(basedir "$name")"
      filename_baseid "$name" && echo "$id $name"
    done | sort -u | join_lines - ' '
}

package_lists_contexts_map() #
{
  local local_name="$1"
  while test -z "$2"
  do
    upper=0 mkvid "package_lists_contexts_map_$local_name" ;
    set -- $( eval echo \"\$$vid\" )
    test -z "$1" || echo "$1"
    local_name="$(dirname "$local_name")"
    test "$local_name" != "/" -a "$local_name" != "." || break
  done
}

# Id: script-mpe/0.0.4-dev package.lib.sh
