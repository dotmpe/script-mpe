#!/bin/sh


tools_lib_load()
{
  true # upper=0 default_env out-fmt tty || true
}

tools_json()
{
  test -e $HTD_TOOLSFILE || return $?
  test $HTD_TOOLSFILE -ot $B/tools.json \
    || jsotk.py yaml2json $HTD_TOOLSFILE $B/tools.json
}

tools_json_schema()
{
  default_env Htd-ToolsSchemaFile ~/bin/schema/tools.yml
  test -e $HTD_TOOLSSCHEMAFILE || return $?
  test $HTD_TOOLSSCHEMAFILE -ot $B/tools-schema.json \
    || jsotk.py yaml2json $HTD_TOOLSSCHEMAFILE $B/tools-schema.json
}

tools_list()
{
  echo $(
      jsotk.py -O lines keys $B/tools.json tools || return $?
    )
}

# Check if binary is available for tool
installed()
{
  test -e "$1" || error installed-arg1 1
  test -n "$2" || error installed-arg2 1
  test -z "$3" || error "installed-args:$3" 1

  # Get one name if any
  local bin="$(jsotk.py -sq -O py path $1 tools/$2/bin)"
  test -z "$bin" -o "$bin" = "True" && bin="$2"
  test -n "$bin" || {
    warn "Not installed '$2' (bin/$bin)"
    return 1
  }

  case "$bin" in
    "["*"]" )
        local k="htd:installed:$1:$2"
        stderr ok "$sd_be($k): $(statusdir.sh set "$k" 0 180)"

        # Or a list of names
        jsotk.py -O py items $1 tools/$2/bin | while read bin_
        do
          test -n "$bin_" || continue
          test -n "$(eval echo "$bin_")" || warn "No value for $bin_" 1
          test -n "$(eval which $bin_)" && {
            statusdir.sh incr "htd:installed:$1:$2"
          }
        done

        count=$(statusdir.sh get htd:installed:$1:$2)
        test -n "$count" -a 0 -ne $count || return 1

        return 0;
      ;;
  esac

  test -n "$(eval echo "$bin")" || warn "No value for $bin" 1
  test -n "$(eval which $bin)" && return
  #local version="$(jsotk.py objectpath $1 '$.tools.'$2'.version')"
  #$bin $version && return || break

  return 1;
}

install_bin()
{
  test -e "$1" || error install-bin-arg1 1
  test -n "$2" || error install-bin-arg2 1
  test -z "$3" || error "install-bin-args:$3" 1

  installed "$@" && return

  # Look for installer
  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  test -n "$installer" || return 3
  test -n "$installer" && {
    id="$(jsotk.py -N -O py path $1 tools/$2/id)"
    test -n "$id" || id="$2"
    debug "installer=$installer id=$id"
    case "$installer" in

      brew )
          brew install $id || return 2
          brew link $id || return 2
        ;;

      npm )
          npm install -g $id || return 2
        ;;

      pip )
          pip install --user $id || return 2
        ;;

      git )
          url="$(jsotk.py -N -O py path $1 tools/$2/url)"
          test -d $HOME/.htd-tools/cellar/$id || (
            git clone $url $HOME/.htd-tools/cellar/$id
          )
          (
            cd $HOME/.htd-tools/cellar/$id
            git pull origin master
          )
          bin="$(jsotk.py -N -O py path $1 tools/$2/bin)"
          src="$(jsotk.py -N -O py path $1 tools/$2/src)"
          test -n "$src" || src=$bin
          (
            cd $HOME/.htd-tools/bin
            test ! -e $bin || rm $bin
            ln -s $HOME/.htd-tools/cellar/$id/$src $bin
          )
        ;;

      * ) error "No installer '$installer'" 1 ;;
    esac
  } || {
    jsotk.py objectpath $1 '$.tools.'$2'.install'
  }

  jsotk.py items $1 tools/$2/post-install | while read scriptline
  do
    scr=$(echo $scriptline | cut -c2-$(( ${#scriptline} - 1 )) )
    note "Running '$scr'.."
    eval $scr || exit $?
  done
}

uninstall_bin()
{
  test -e "$1" || error uninstall-bin-arg1 1
  test -n "$2" || error uninstall-bin-arg2 1
  test -z "$3" || error uninstall-bin-args 1

  installed "$@" || return 0

  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  test -n "$installer" || return 3
  test -n "$installer" && {
    id="$(jsotk.py -N -O py path $1 tools/$2/id)"
    debug "installer=$installer id=$id"
    test -n "$id" || id=$2
    case "$installer" in
      npm )
          npm uninstall -g $id || return 2
        ;;
      pip )
          pip uninstall $id || return 2
        ;;
    esac
  }

  jsotk.py items $1 tools/$2/post-uninstall | while read scriptline
  do
    note "Running '$scriptline'.."
    eval $scriptline || exit $?
  done
}

htd_tools_list()
{
  tools_list
}

htd_tools_installed()
{
  test -n "$1" || set -- $(tools_list) ; test -n "$*" || return 2 ;
  test "$out_fmt" = "yml" && echo "tools:" ; while test -n "$1"
  do
    installed $B/tools.json "$1" && {
      note "Tool '$1' is present"
      test "$out_fmt" = "yml" && printf "  $1:\n    installed: true\n" || noop
    } || {
      test "$out_fmt" = "yml" && printf "  $1:\n    installed: false\n" || noop
    }
    shift
  done
}

htd_tools_install()
{
  local verbosity=6
  while test -n "$1"
  do
    install_bin $B/tools.json $1 \
      && info "Tool $1 is installed" \
      || info "Tool $1 install error: $?"
    shift
  done
}

htd_tools_uninstall()
{
  local verbosity=6
  while test -n "$1"
  do
    uninstall_bin $B/tools.json "$1" \
      && info "Tool $1 is not installed" \
      || { r=$?;
        test $r -eq 1 \
          && info "Tool $1 uninstalled" \
          || info "Tool uninstall $1 error: $r" $r
      }
    shift
  done
}

htd_tools_validate()
{
  tools_json_schema || return 1
  # Note: it seems the patternProperties in schema may or may not be fouling up
  # the results. Going to venture to outline based format first before returning
  # to which JSON schema spec/validator supports what.
  jsonschema -i $B/tools.json $B/tools-schema.json &&
      stderr ok "jsonschema" || stderr warn "jsonschema"
  jsonspec validate --document-file $B/tools.json \
    --schema-file $B/tools-schema.json &&
      stderr ok "jsonspec" || stderr warn "jsonspec"
}
