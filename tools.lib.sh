#!/bin/sh

## Named deps

tools_lib_load ()
{
  #upper=0 default_env out-fmt tty
  test -n "${out_fmt-}" || export out_fmt=tty

  # default_env Htd-ToolsFile "$CWD/tools.yml"
  test -n "${HTD_TOOLSFILE-}" || export HTD_TOOLSFILE="$PWD"/tools.yml

  # default_env Htd-BuildDir .build
  test -n "${HTD_BUILDDIR-}" || export HTD_BUILDDIR="$PWD/.build"
  export B="$HTD_BUILDDIR"

  # default_env Htd-ToolsDir "$HOME/.htd-tools"
  test -n "${HTD_TOOLSDIR-}" || export HTD_TOOLSDIR=$HOME/.htd-tools
}

tools_lib_init () # [B] ~
{
  test -d $B || mkdir -p $B
  default_env Htd-ToolsSchemaFile ~/bin/schema/tools.yml
  tools_json
}

# Create $B/tools.json from HTD_TOOLSFILE yaml
tools_json () # [HTD_TOOLSFILE] [B] ~
{
  test -e $HTD_TOOLSFILE || return $?
  test $HTD_TOOLSFILE -ot $B/tools.json \
    || {
        $LOG info "" "Converting" "jsotk.py yaml2json $HTD_TOOLSFILE $B/tools.json"
        jsotk.py yaml2json $HTD_TOOLSFILE $B/tools.json
  }
}

tools_json_schema () # [B] [HTD_TOOLSSCHEMAFILE]
{
  test -e $HTD_TOOLSSCHEMAFILE || return $?
  test $HTD_TOOLSSCHEMAFILE -ot $B/tools-schema.json \
    || jsotk.py yaml2json $HTD_TOOLSSCHEMAFILE $B/tools-schema.json
}

tools_list () # [B] ~
{
  echo $(
      jsotk.py -O lines keys $B/tools.json tools || return $?
    )
}

# Check if binary is available for tool
tools_installed () # ~ Tools-JSON Tool-Id
{
  test $# -eq 2 -a -e "$1" -a -n "$2" || return

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

tools_install () # ~ Tools-JSON Tool-Id
{
  test $# -eq 2 -a -e "$1" -a -n "$2" || return

  tools_installed "$@" && return

  # Look for installer
  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  true "${installer:=sh}"
  id="$(jsotk.py -N -O py path $1 tools/$2/id)"
  test -n "$id" || id="$2"
  debug "installer=$installer id=$id"
  func_exists tools_${installer^^}_install ||
    error "No installer '$installer'" 1
  tools_${installer^^}_install "$@"
  eval "$(jsotk.py -O lines items $1 tools/$2/post-install)"
  # XXX: cleanup
  #jsotk.py items $1 tools/$2/post-install | while read scriptline
  #do
  #  scr=$(echo $scriptline | cut -c2-$(( ${#scriptline} - 1 )) )
  #  note "Running '$scr'.."
  #  eval $scr || exit $?
  #done
}

tools_SH_install ()
{
  eval "$(jsotk.py -O lines items $1 tools/$2/install)"
}

tools_BREW_install ()
{
  brew install $id &&
  brew link $id
}

tools_NPM_install ()
{
  npm install -g $id
}

tools_PIP_install ()
{
  pip install --user $id
}

tools_GIT_install ()
{
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
}


tools_uninstall () # ~ Tools-JSON Tool-Id
{
  test $# -eq 2 -a -e "$1" -a -n "$2" || return
  tools_installed "$@" || return 0
  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  true "${installer:=sh}"
  id="$(jsotk.py -N -O py path $1 tools/$2/id)"
  test -n "$id" || id=$2
  debug "uninstall installer=$installer id=$id"
  func_exists tools_${installer^^}_uninstall ||
    error "No uninstaller '$installer'" 1
  tools_${installer^^}_uninstall "$@"
  jsotk.py items $1 tools/$2/post-uninstall | while read scriptline
  do
    note "Running '$scriptline'.."
    eval $scriptline || exit $?
  done
}

tools_SH_uninstall ()
{
  eval "$(jsotk.py -O lines items $1 tools/$2/uninstall)"
}

tools_BASHER_uninstall ()
{
  basher uninstall $id
}

tools_NPM_uninstall ()
{
  npm uninstall -g $id
}

tools_PIP_uninstall ()
{
  pip uninstall --user $id
}

tools_generate_script () # ~ Tools-JSON Tool-Id
{
  local installer
  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  true "${installer:=sh}"
  id="$(jsotk.py -N -O py path $1 tools/$2/id)"
  test -n "$id" || id=$2
  func_exists tools_${installer^^}_generate_script ||
    error "No generate-script '$installer'" 1
  tools_${installer^^}_generate_script "$@"
}

tools_SH_generate_script ()
{
  local vid ; mkvid "$id"
  for script in install uninstall
  do
    cat <<EOM
${script}_${vid} ()
{
$( jsotk.py -O lines items $1 tools/$2/$script | sed 's/^/  /')
$( jsotk.py -O lines items $1 tools/$2/post-$script | sed 's/^/  /')
}
EOM
  done
}

tools_BASHER_generate_script ()
{
  local vid ; mkvid "$id"
  cat <<EOM
install_${vid} ()
{
  basher install $id
$( jsotk.py -O lines items $1 tools/$2/post-install | sed 's/^/  /')
}

uninstall_${vid} ()
{
  basher uninstall $id
$( jsotk.py -O lines items $1 tools/$2/post-uninstall | sed 's/^/  /')
}
EOM
}

tools_PIP_generate_script ()
{
  local vid ; mkvid "$id"
  cat <<EOM
install_${vid} ()
{
  pip install $id
$( jsotk.py -O lines items $1 tools/$2/post-install | sed 's/^/  /')
}

uninstall_${vid} ()
{
  pip uninstall $id
$( jsotk.py -O lines items $1 tools/$2/post-uninstall | sed 's/^/  /')
}
EOM
}

tools_depends () # ~ Tools-JSON Tool-Id
{
  test $# -eq 2 -a -e "$1" -a -n "$2" || return
  installer="$(jsotk.py -N -O py path $1 tools/$2/installer)"
  test "${installer:-"sh"}" = "sh" || echo "$installer"
  jsotk.py -N -O py path $1 tools/$2/depends | tr ' ' '\n'
}
