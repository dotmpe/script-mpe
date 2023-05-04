#!/bin/sh

# File and path ignore rules


ignores_lib__load()
{
  # XXX: default_env Script-Etc "$( { htd_init_etc || ignore_sigpipe $?; } | head -n 1 )" ||
  #  debug "Using Script-Etc '$SCRIPT_ETC'"
  true "${SCRIPT_ETC:="$( { htd_init_etc || ignore_sigpipe $?; } | head -n 1)"}"

  #test -n "$SCRIPT_ETC" -a -e "$SCRIPT_ETC" ||
  #    error "ignores: SCRIPT-ETC '$SCRIPT_ETC'" 2

  true "${IGNORES_CACHE_DIR:=".meta/cache"}"

  # Ignore any directoyr that has this entry
  test -n "${IGNORE_DIR-}" || IGNORE_DIR=.ignore-dir

  test -n "${Path_Ignores-}" ||
      Path_Ignores=$IGNORES_CACHE_DIR/ignores.globlist

  Ignore_Groups="global local scm"
}

ignores_lib__init()
{
  test "${ignores_lib_init-}" = "0" && return

  # Begin with an initial IGNORE_GLOBFILE value with local filename based on
  # frontend, i.e. for `htd` this simply is HTD_IGNORE=.htdignore
  ignores_init "$base"
}


ignores_cache ()
{
  { test -e "$Path_Ignores" && newer_than "$Path_Ignores" $_1DAY
  } || {
    ignores_refresh
  }
}

ignores_refresh () # ~ [GROUPS]
{
  test $# -gt 0 || set -- $Ignore_Groups
  ignores_cat "$@" > "$Path_Ignores"
}

ignores_init()
{
  test -n "${1-}" || return
  test -n "${2-}" || set -- $1 $(str_upper $1)

  local varname=$(echo $2 | tr '-' '_')_IGNORE fname=.${1}ignore

  export IGNORE_GLOBFILE_VAR=$varname
  export IGNORE_GLOBFILE="$(try_var "$IGNORE_GLOBFILE_VAR")"
  test -z "$DEBUG" || {
    test -n "$IGNORE_GLOBFILE" || warn "No IGNORE_GLOBFILE for $varname set"
  }

  eval $varname=\"\${$varname-$fname}\"
  local value="$(eval echo "\$$varname")"

  # XXX: why use tmp?
  test -e "$value" || {
    value=$(setup_tmpf $fname)
    eval $varname=$value
    touch $value
  }
  export $varname
}

# Keys for ignores-groups
ignores_group_names()
{
  echo local global
  echo purge clean drop
  echo tracked ignored untracked
}

# Map group tags to filenames.
# TODO: would be nice to have something extendable/customizable groups (list file paths)
ignores_groups()
{
  while test $# -gt 0
  do
    case "$1" in
      purge ) set -- "$@" local-purge global-purge ;;
      clean ) set -- "$@" local-clean global-clean ;;
      drop ) set -- "$@"  local-drop global-drop ;;

      ignore ) echo ".ignore" ;;

      local ) set -- "$@" ignore local-clean local-purge local-drop ;;
      local-clean )
          echo $IGNORE_GLOBFILE-cleanable
          echo $IGNORE_GLOBFILE-clean
        ;;
      local-drop )
          echo $IGNORE_GLOBFILE-droppable
          echo $IGNORE_GLOBFILE-drop
        ;;
      local-purge )
          echo $IGNORE_GLOBFILE-purgeable
          echo $IGNORE_GLOBFILE-purge
        ;;

      global ) set -- "$@" global-clean global-purge global-drop ;;
      global-clean ) echo etc:cleanable.globs ;;
      global-purge ) echo etc:purgeable.globs ;;
      global-drop ) echo etc:droppable.globs ;;

      scm ) set -- "$@" $1-git $1-bzr $1-svn ;;
      scm-git ) set -- "$@" $1-global $1-local ;;
      scm-git-global )
          echo ~/.gitignore-global
          echo ~/.gitignore-clean-global
          echo ~/.gitignore-temp-global
        ;;
      scm-git-local )
          echo .gitignore
          echo .git/info/exclude
          # TODO: .attributes see pd:list-paths opts parsing;
        ;;

      scm-svn ) ;;
      scm-hg ) ;;
      scm-bzr )
          echo .bzrignore
        ;;

      * ) error "Unhandled ignores-group '$*'" 1 ;;
    esac
    shift
  done | remove_dupes
}

ignores_groups_exist()
{
  set -- $(ignores_groups "$@" | lines_to_words ) # Remove options, resolve args
  note "Resolved ignores to '$*'"

  while test $# -gt 0
  do
    case "$1" in

      etc:* )
            test -e \
              "$SCRIPT_ETC/htd/list-ignores/$(echo "$1" | cut -c5-)" || {
                  shift; continue; }
          ;;

      * )
            test -e "$1" || { shift; continue; }
          ;;

    esac
    echo "$1"
    shift
  done
}

# Convenient access to glob lists (cat files)
ignores_cat () # ~ FILES...
{
  local src_a="$*"
  set -- $(ignores_groups "$@" | lines_to_words ) # Remove options, resolve args
  note "Resolved ignores source '$src_a' to files '$*'"

  while test $# -gt 0
  do
    case "$1" in

      etc:* )
          read_if_exists \
            "$SCRIPT_ETC/htd/list-ignores/$(echo "$1" | cut -c5-)" ||
              note "Nothing to read for '$1'" ;;

      * )
          read_if_exists "$1" ;;

    esac
    shift
  done
}

glob_to_find_prune()
{
  test -n "$1" || return

  case "$1" in
      /*/ ) echo "-o -path \"$1*\" -a -prune" ;;
      */ ) echo "-o -path \"*/$1*\" -a -prune" ;;
      /* ) echo "-o -path \"$1*\" -a -prune" ;;
      */* ) echo "-o -path \"*/$1*\" -a -prune" ;;
      * ) echo "-o -name \"$1\" -a -prune" ;;
  esac
}

# Return find ignore flags for given exclude pattern file
ignores_find ()
{
  for a in "$@"
  do
    test -e "$a" || {
        $LOG error "" "No such file" "$a"; return 1; }
    # Translate gitignore lines to find flags
    read_nix_style_file $a | while read glob
      do glob_to_find_prune "$glob"; done
  done | grep -Ev '^(#.*|\s*)$'
}
