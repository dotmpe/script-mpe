#!/bin/sh

## Named deps

tools_lib__load ()
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

tools_lib__init () # [B] ~
{
  test -d "$B" || stderr mkdir -vp $B
  default_env Htd-ToolsSchemaFile ~/bin/schema/tools.yml &&
  tools_json || return

  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized tools.lib" "$(sys_debug_tag)"
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

tools_generate_script () # [Tools-JSON] [Script-Tpl] [Args...]
{
  local TOOLS_JSON="${1-}" TOOLS_SCR_TPL="${2-}"
  test -n "${TOOLS_JSON}" || TOOLS_JSON="$B/tools.json"
  test -n "${TOOLS_SCR_TPL}" || TOOLS_SCR_TPL="tools.install-deps.scr"

  test $# -eq 0 || { test $# -eq 1 && shift ; } || shift 2

  source $TOOLS_SCR_TPL

  echo "# Generated at $(date --iso=min) using $TOOLS_SCR_TPL"
}

# List all installable tool Ids
tools_list () # [B] ~ [tools.json]
{
  test $# -le 1 || return 64
  test -n "${1-}" || set -- $B/tools.json
  # 'required' entries dont have an installer option itself
  jq -r '.tools | to_entries[] | select(.value.required==null) | .key' "$1"
}

# List every tool Id, including prerequisites
tools_list_all () # [B] ~ [tools.json]
{
  test $# -le 1 || return 64
  test -n "${1-}" || set -- $B/tools.json
  jsotk.py -O lines keys "$1" tools
}

# Check if binary is available for tool
tools_installed () # [B] ~ [Tools-JSON] Tool-Id
{
  test $# -le 2 -a -n "${2-}" || return 64
  test -n "${1-}" || set -- $B/tools.json "$2"

  tools_m_exists "$1" "$2" || {
    warn "No installable '$2' ($1)"
    return 1
  }
  local bin="$(tools_bin "$1" "$2")"

  # FIXME: can bin be a list? Nah...
  case "$bin" in
    "["*"]" )
        local k="htd:installed:$1:$2"
        stderr ok "$sd_be($k): $(statusdir.sh set "$k" 0 180)"

        # Or a list of names
        jsotk.py -O py items $1 tools/\"$2\"/bin | while read bin_
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

tools_load () # ~ Tools-JSON Installer-Id
{
  func_exists tools_${installer^^}_install ||
    error "No installer '$installer'" 1
}

tools_install_new () # ~ Tools-JSON Tool-Id
{
  func_exists tools_${installer^^}_install ||
    error "No installer '$installer'" 1
}

tools_install () # ~ Tools-JSON Tool-Id
{
  test $# -eq 2 -a -e "$1" -a -n "$2" || return

  tools_installed "$@" && return

  # Look for installer
  installer="$(jsotk.py -N -O py path $1 tools/\"$2\"/installer)"
  true "${installer:=sh}"
  id="$(jsotk.py -N -O py path $1 tools/\"$2\"/id)"
  test -n "$id" || id="$2"
  debug "installer=$installer id=$id"
  func_exists tools_${installer^^}_install ||
    error "No installer '$installer'" 1
  tools_${installer^^}_install "$@"
  eval "$(jsotk.py -O lines items $1 tools/\"$2\"/post-install)"
  # XXX: cleanup
  #jsotk.py items $1 tools/\"$2\"/post-install | while read scriptline
  #do
  #  scr=$(echo $scriptline | cut -c2-$(( ${#scriptline} - 1 )) )
  #  note "Running '$scr'.."
  #  eval $scr || exit $?
  #done
}

tools_SH_install ()
{
  eval "$(jsotk.py -O lines items $1 tools/\"$2\"/install)"
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
  repo="$(jsotk.py -N -O py path $1 tools/\"$2\"/repo)" || return
  branch="$(jsotk.py -N -O py path $1 tools/\"$2\"/branch 2>/dev/null || echo master)"
  base="$(jsotk.py -N -O py path $1 tools/\"$2\"/base 2>/dev/null)"
  test -n "$base" || {
    repo_slug="$(basename "$(dirname "$repo")")/$(basename "$repo" .git)"
    base=$SRC_PREFIX/$repo_slug
  }
  test -d "$base" || {
    git clone "$repo" "$base" || return
  }
  (
    cd "$base" && git checkout "$branch"
  ) || return
}

# FIXME: cleanup
tools_BIN_install () # ~ Tools-JSON Tool-Id
{
  # TODO: move to git+bin?
  bin="$(jsotk.py -N -O py path $1 tools/\"$2\"/bin)"
  src="$(jsotk.py -N -O py path $1 tools/\"$2\"/src)"
  test -n "$src" || src="$bin"
  (
    test -h "$src " || {
      cd "$base" &&
      test ! -e "$bin"
      #ln -s $HTD_TOOLSDIR/cellar/$id/$src $bin
    }
  )
}

tools_uninstall () # ~ Tools-JSON Tool-Id
{
  test $# -eq 2 -a -e "$1" -a -n "$2" || return
  tools_installed "$@" || return 0
  installer="$(jsotk.py -N -O py path $1 tools/\"$2\"/installer)"
  true "${installer:=sh}"
  id="$(jsotk.py -N -O py path $1 tools/\"$2\"/id)"
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

tools_SH_uninstall () # ~ Tools-JSON Tool-Id
{
  eval "$(jsotk.py -O lines items $1 tools/\"$2\"/uninstall)"
}

tools_BASHER_uninstall () # id ~
{
  basher uninstall $id
}

tools_NPM_uninstall () # id ~
{
  npm uninstall -g $id
}

tools_PIP_uninstall () # id ~
{
  pip uninstall --user $id
}

tools_generate_tool () # ~ Tools-JSON Tool-Id
{
  local installer id="$2" toolid
  str_vword toolid "$id"
  installer="$(tools_m_installer "$@")"

  local vid installerid
  str_vword installerid "$installer"

  lib_load tools-installers

  func_exists tools_${installerid^^}_gen ||
    error "No generate-script '$installer'" 1

  tools_${installerid^^}_gen "$@" "$vid"
  #tools_${installerid^^}_generate_script "$@"
}

tools_generate_script_function () # >body ~ Func-Name
{
  cat <<EOM
$1 ()
{
$(cat -)
}


EOM
}

tools_generate_script_function_from_json () # ~ Tools-JSON Tool-Id Key
{
  # FIXME: jsotk.py -qs path --is-new $1 tools/\"$2\"/post-$3 && return
  { jsotk.py -qs path --is-str $1 tools/\"$2\"/$3 && {
    jsotk.py -O py path $1 tools/\"$2\"/$3
  } || {
    jsotk.py -O lines items $1 tools/\"$2\"/$3
  }; } | sed 's/^/  /'
}

tools_generate_script_function_post () # ~ Tools-JSON Tool-Id
{
  tools_generate_script_function_from_json "$1" "$2" post-$3
}

tools_SH_generate_script () # toolid ~ Tools-JSON Tool-Id
{
  local script
  for script in install uninstall
  do
    jsotk.py -qs path $1 tools/\"$2\"/$script || continue
    tools_generate_script_function ${script}_${toolid} <<EOM
  test \$# -eq 0 || return 64
$( tools_generate_script_function_from_json "$1" "$2" $script | sed 's/^/  /')
EOM
  done
}

tools_BASHER_generate_script () # toolid ~ Tools-JSON Tool-Id
{
  local package="$(jsotk.py -N -O py path $1 tools/\"$2\"/package 2>/dev/null)"
  test -n "$package" || package=$id

  tools_generate_script_function install_${toolid} <<EOM
  basher install $package
$(tools_generate_script_function_post "$@" install)
EOM

  tools_generate_script_function uninstall_${toolid} <<EOM
  basher uninstall $package
$(tools_generate_script_function_post "$@" uninstall)
EOM

  tools_generate_script_function update_${toolid} <<EOM
  basher upgrade $package
$(tools_generate_script_function_post "$@" update)
EOM
}

tools_PIP_generate_script () # toolid ~
{
  tools_generate_script_function install_${toolid} <<EOM
  pip install $id
$(tools_generate_script_function_post "$@" install)
EOM

  tools_generate_script_function uninstall_${toolid} <<EOM
  pip uninstall $id
$(tools_generate_script_function_post "$@" uninstall)
EOM
}

tools_APT_generate_script () # toolid ~
{
  tools_generate_script_function install_${toolid} <<EOM
  apt install $id
$(tools_generate_script_function_post "$@" install)
EOM

  tools_generate_script_function uninstall_${toolid} <<EOM
  apt uninstall $id
$(tools_generate_script_function_post "$@" uninstall)
EOM

  tools_generate_script_function update_${toolid} <<EOM
  apt upgrade -y $id
$(tools_generate_script_function_post "$@" update)
EOM
}

tools_GIT_generate_script () # toolid ~
{
  local repo="$( jsotk.py -N -O py path $1 tools/\"$2\"/repo )"
  local base=$( jsotk.py -N -O py path $1 tools/\"$2\"/base 2>/dev/null )
  test -n "$base" || base="\$SRC_PREFIX/$2"

  tools_generate_script_function install_${toolid} <<EOM
  test -n "\${${toolid^^}_REPO-}" || ${toolid^^}_REPO=$repo
  test -n "\${${toolid^^}_BRANCH-}" || ${toolid^^}_BRANCH=$( jsotk.py -N -O py path $1 tools/\"$2\"/branch 2>/dev/null || echo master )
  test -n "\${${toolid^^}_BASE-}" || ${toolid^^}_BASE=$base

  test -d "\$${toolid^^}_BASE" || {
    git clone "\$${toolid^^}_REPO" "\$${toolid^^}_BASE" || return
  }
  (
    cd "\$${toolid^^}_BASE" &&
    git checkout "\$${toolid^^}_BRANCH"
  ) || return
$(tools_generate_script_function_post "$@" install)
EOM

  tools_generate_script_function uninstall_${toolid} <<EOM
  test -n "\${${toolid^^}_BASE-}" || ${toolid^^}_BASE=$base
  rm -rf "\$${toolid^^}_BASE"
$(tools_generate_script_function_post "$@" uninstall)
EOM

  tools_generate_script_function update_${toolid} <<EOM
  test -n "\${${toolid^^}_BASE-}" || ${toolid^^}_BASE=$base
  test -n "\${${toolid^^}_BRANCH-}" || ${toolid^^}_BRANCH=$( jsotk.py -N -O py path $1 tools/\"$2\"/branch 2>/dev/null || echo master )
  (
    cd "\$${toolid^^}_BASE" &&
    git pull origin "\$${toolid^^}_BRANCH"
  ) || return
$(tools_generate_script_function_post "$@" update)
EOM
}

tools_CURL_SH_generate_script () # toolid ~
{
  tools_generate_script_function install_${toolid} <<EOM
  test -n "\${${toolid^^}_SH_URL-}" || ${toolid^^}_SH_URL=$( jsotk.py -N -O py path $1 tools/\"$2\"/url )
  curl -sf "\$${toolid^^}_SH_URL" | bash -
$(tools_generate_script_function_post "$@" install)
EOM
  # TODO: uninstall/update URL?
}

tools_m_bin () # ~ Tools-JSON Tool-Id
{
  local bin="$(jsotk.py -O py path "$1" "tools/\"$2\"/bin" 2>/dev/null)"
  test "$bin" = "False" && return 1
  test "$bin" = "True" && bin=
  test -z "$bin" && bin="${2,,}"
  echo "$bin"
}

tools_m_depends () # ~ Tools-JSON Tool-Name-Id
{
  test $# -eq 2 -a -e "$1" -a -n "$2" || return 64
  local dep installer="$(tools_m_installer "$@")"
  test "${installer:-"sh"}" = "sh" || {
    tools_m_depends $1 $installer
    echo "$installer"
  }
  {
    jsotk.py -qs path --is-list $1 tools/\"$2\"/depends && {
      jsotk.py -O lines items $1 tools/\"$2\"/depends
    } || {
      jsotk.py -O py path $1 tools/\"$2\"/depends 2>/dev/null
  }; } |
    tr ' ' '\n' | while read dep
      do
        tools_m_depends $1 $dep
        echo "$dep"
      done
}

tools_m_exists () # ~ Tools-JSON Tool-Id
{
  jsotk.py path --is-obj "$1" "tools/\"$2\""
}

tools_m_installer () # Tools-JSON Tool-Name-Id
{
  tools_m_vardef "$1" "$2" "installer" "sh"
}

tools_m_required () # ~ Tools-JSON Tool-Id
{
  local required="$(jsotk.py -O py path "$1" "tools/\"$2\"/required" 2>/dev/null)"
  test "$required" != "False" && echo 1 || echo 0
}

tools_m_vardef () # Tools-JSON Tool-Name-Id Sub-Path [Default]
{
  test $# -ge 3 || return 64
  local v
  v="$( jsotk.py -N -O py path "$1" "tools/\"$2\"/$3" 2>/dev/null )"
  test $# -eq 3 || true "${v:=$4}"
  test -z "$v" || echo "$v"
}
