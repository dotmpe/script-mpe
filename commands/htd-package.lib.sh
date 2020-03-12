#!/bin/sh

htd_man_1__package='Get local (project/workingdir) metadata

  package ls|list-ids
     List package IDs from local package metadata file.
  package update
     Regenerate main.json/PackMeta-JS-Main and package.sh/PackMeta-Sh files from YAML
  package write-script NAME
     Write env+script lines to as-is executable shell script for "scripts/NAME"
  package write-scripts NAMES
     Write scripts.
  package remotes-init
     Take all repository names/urls directly from YAML, and create remotes or
     update URL for same in local repository. The remote name and exact
     remote-url is determined with htd-repository-url (htd.lib.sh).
  package remotes-reset
     Remove all remotes and reset
  package urls
     TODO: List URLs for package.
  package openurl|open-url [URL]
     ..
  package debug
     Log each Sh package settings.
  package scripts-write [NAME]
     Compile script into as-is shell script.

Plumbing
  package sh-script SCRIPTNAME [PackMeta-JS-Main]
     List script lines
  package sh-env
     List profile script lines from PackMeta-Sh
  package sh-env-script
     Update env profile script from sh-env lines

  package dir-get-key <Dir> <Package-Id> [<Property>...]

Plumbing commands dealing with the local project package file. See package.rst.
These do not auto-update intermediate artefacts, or load a specific package-id
into env.
'
htd_package__help ()
{
  echo "$htd_man_1__package"
}


htd_package_list_ids()
{
  test -e "${PACKMETA-}" || error "htd-package-list-ids no file '$PACKMETA'" 1
  jsotk.py -I yaml -O py objectpath $PACKMETA '$.*[@.id is not None].id'
}


htd_package_update()
{
  test $# -le 1 || return
  test $# -eq 1 || set -- .
  update_package $1
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
        package_sh_list_exists "$k" || continue
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

# List strings at main package 'urls' key
htd_package_urls()
{
  test -n "${PACKMETA_SH-}" || package_lib_set_local "$(pwd -P)"
  test -e "${PACKMETA_JS_MAIN-}" || error "No '$PACKMETA_JS_MAIN' file" 1
  jsotk.py path -O pkv "$PACKMETA_JS_MAIN" urls
}

htd_package_open_url()
{
  test -n "${1-}" || error "name expected" 1
  test -n "${PACKMETA_SH-}" || package_lib_set_local "$(pwd -P)"
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
  test -n "${PACKMETA_SH-}" || package_lib_set_local "$(pwd -P)"
  test -e "${PACKMETA_JS_MAIN-}" || error "No '$PACKMETA_JS_MAIN' file" 1
  vc_getscm
  jsotk.py path -O pkv "$PACKMETA_JS_MAIN" repositories |
      tr '=' ' ' | while read -r remote url
  do
    # Get rid of quotes, but don't interpolate ie. expand home?
    eval "remote=$remote url=$url"

    test -n "$remote" -a -n "$url" || {
      warn "empty package repo var '$remote $url'"; continue; }
    # NOTE: multitype repo projects? determine type per suffix..
    fnmatch "*.$scm" "$url" || continue

    debug "scm: $scm; remote: '$remote' url: '$url'"
    htd_repository_url "$remote" "$url" || continue
    std_info "remote: '$remote' url: '$url'"
    vc_git_update_remote "$remote" "$url"
  done
}

htd_package_remotes_reset()
{
  test -n "${PACKMETA_SH-}" || package_lib_set_local "$(pwd -P)"
  git remote | while read -r remote
  do
      git remote remove $remote && std_info "Removed '$remote'"
  done
  note "Removed all remotes, re-adding.."
  htd_package_remotes_init
}

htd_package_write_script() # [env script_out=.htd/scripts/NAME] : NAME
{
  test -n "${1-}" || set -- "init"
  test -n "${script_out-}" || script_out=.htd/scripts/$1.sh
  test -n "${PACKMETA_SH-}" || package_lib_set_local "$(pwd -P)"

  test -s $script_out -a $script_out -nt $PACKMETA && {
    note "Newest version of $script_out exists"

  } || {
    . "$PACKMETA_SH"
    upper=0 mkvid "$1"
    test -n "$package_shell" || package_shell="$default_package_shell"
    mkdir -vp "$(dirname "$script_out")" &&
    #trueish "$script_line_eval" && { {
        {
            echo "#!$package_shell"
            package_sh_list_exists "scripts_$vid" && {
                package_sh_list "$PACKMETA_SH" "scripts_$vid"
            } || {
                package_sh_name_exists "scripts_$vid" && {
                    package_sh_get "$PACKMETA_SH" "scripts_$vid"
                } || {
                    rm "$script_out"
                    error "No multi-line script '$1'" 1
                }
            }
        } >"$script_out"
    #} || {
    #  { echo "#!$package_shell" ;

    #      package_sh_name_exists && {
    #        package_sh_get "$PACKMETA_SH" "scripts_$vid"
    #      } || {
    #        rm "$script_out"
    #        error "No script line '$1'" 1
    #      }
    #  } >"$script_out"
    #}
    note "Updated $script_out"
  }
  unset script_out
}

htd_package_write_scripts() # NAMES...
{
  # Init env, update package if stale, if not set yet
  test -n "${PACKMETA_SH-}" || package_lib_set_local "$(pwd -P)"
  # Handle options
  test -z "$no_eval" || eval=0
  test -z "$eval" || show_eval=$eval
  # Source package if not set and start
  test -n "$package_main" || . $PACKMETA_SH

  # Create/update shell profile script
  package_sh_env_script

  while test $# -gt 0
  do
    htd_package_write_script "$1" || return
    shift
  done
}

# Initialize package.yaml file, using values `from` extractors
htd_package_init() #
{
  case "$from" in

    git ) htd_package_from_$from ;;

    * ) error "no such 'from' value '$from'" 1 ;;
  esac
}

# Initialize package.yaml from (local) GIT checkout
htd_package_from_git() # [DIR=. [REMOTE [FROM...]]]
{
  htd_package_print_from_git "$@" > $PACKMETA
}

# TODO; See htd-package-init
htd_package_print_from_git() # [DIR=. [REMOTE [FROM...]]]
{
  # Get ID for package from primary (default) remote

  # Find first/root commit (date(s))
  # Echo package meta and remotes list
  echo
}
