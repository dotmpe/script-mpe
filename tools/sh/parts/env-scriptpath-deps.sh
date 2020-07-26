#!/bin/sh

# Add script-packages (from dependencies.txt) to SCRIPTPATH

test -n "${INIT_LOG-}" || return 109

test -z "${SCRIPTPATH-}" ||
  $INIT_LOG "note" "env-scriptpath-deps" "Current SCRIPTPATH" "$SCRIPTPATH"

type trueish >/dev/null 2>&1 || {
  . $sh_tools/parts/trueish.sh
}
type remove_dupes >/dev/null 2>&1 || {
  . $sh_tools/parts/remove-dupes.sh
}
type unique_paths >/dev/null 2>&1 || {
  . $sh_tools/parts/unique-paths.sh
}
type script_package_include >/dev/null 2>&1 || {
  . $sh_tools/parts/script-package-include.sh
}

test -n "${SH_EXT-}" || {
  test -n "${REAL_SHELL-}" ||
    REAL_SHELL=$(ps --pid $$ --format cmd --no-headers | cut -d' ' -f1)
  SH_EXT=$(basename "$REAL_SHELL")
}

trueish "${ENV_DEV-}" && {
  test -n "${PROJECT_DIR-}" || {
    for pd in $HOME/project /srv/project-local
    do test -d "$pd" || continue
      PROJECT_DIR="$pd"
      break
    done
    unset pd
  }
}

test -n "${VND_PATHS-}" || {
  test -n "${VND_GH_SRC-}" || VND_GH_SRC=/src/github.com
  test -n "${VND_SRC_PREFIX-}" || VND_SRC_PREFIX=/src/local

  VND_PATHS="$(unique_paths ~/build $VND_GH_SRC $VND_SRC_PREFIX ~/.basher/cellar/packages)"
}

# Use dependencies that include sources from dependencies.txt files, ie the git
# and basher ones.

test -n "${PROJECT_DEPS-}" || {
  script_package_include $CWD ||
    $INIT_LOG "error" "" "Error including script-package at $CWD" 1
}

test -n "${PROJECT_DEPS:-}" || PROJECT_DEPS=$CWD/dependencies.txt
# Look for deps at each VND_PATHS, source load.*sh file to let it setup SCRIPTPATH
for supportlib in $(grep -h '^\(git\|basher\) ' $PROJECT_DEPS | cut -d' ' -f2);
do
  # Override VND_PATHS in Dev-Mode with basenames from ~/project that match
  # dependency basename
  trueish "${ENV_DEV-}" && {
    test -d "$PROJECT_DIR/$(basename "$supportlib")" && {
      script_package_include "$PROJECT_DIR/$(basename "$supportlib")" && continue
      $INIT_LOG "error" "" "Error including script-package at $PROJECT_DIR/$(basename "$supportlib")" 1
    }
  }

  # Go over known locations and include user-script packages matching dependency
  for vnd_base in $VND_PATHS
  do
    test -d "$vnd_base/$supportlib" || continue
    script_package_include "$vnd_base/$supportlib" && break
    $INIT_LOG "error" "" "Error including script-package at $vnd_base/$supportlib" 1
  done
done

test -z "${SCRIPTPATH:-}" &&
    $INIT_LOG "error" "" "No SCRIPTPATH found" ||
    $INIT_LOG "note" "" "New SCRIPTPATH from $PROJECT_DEPS" "$SCRIPTPATH"
unset supportlib vnd_base lib_path
export SCRIPTPATH

# Sync: U-S:
