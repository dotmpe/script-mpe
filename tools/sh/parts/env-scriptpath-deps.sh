#!/bin/sh

# Add script-packages (from dependencies.txt) to SCRIPTPATH

test -n "${INIT_LOG:-}" || return 109

test -z "${SCRIPTPATH:-}" ||
  $INIT_LOG note "env-scriptpath-deps" "Current SCRIPTPATH" "$SCRIPTPATH"

type trueish >/dev/null 2>&1 || {
  . $CWD/tools/sh/parts/trueish.sh
}
type remove_dupes >/dev/null 2>&1 || {
  . $CWD/tools/sh/parts/remove-dupes.sh
}
type unique_paths >/dev/null 2>&1 || {
  . $CWD/tools/sh/parts/unique-paths.sh
}
type script_package_include >/dev/null 2>&1 || {
  . $CWD/tools/sh/parts/script-package-include.sh
}

test -n "${SH_EXT-}" || {
  test -n "${REAL_SHELL-}" ||
    REAL_SHELL=$(ps --pid $$ --format cmd --no-headers | cut -d' ' -f1)
  SH_EXT=$(basename "$REAL_SHELL")
}

script_package_include $CWD ||
  $INIT_LOG "error" "" "Error including script-package at $CWD" 1

trueish "$ENV_DEV" && {
  test -n "${PROJECT_DIR-}" || {
    for pd in $HOME/project /srv/project-local
    do test -d "$pd" || continue
      PROJECT_DIR="$pd"
      break
    done
    unset pd
  }
}

test -n "${VND_PATHS-}" ||
  VND_PATHS="$(unique_paths ~/build $VND_GH_SRC $VND_SRC_PREFIX ~/.basher/cellar/packages)"

for supportlib in $(grep '^\(git\|basher\) ' $CWD/dependencies.txt | cut -d' ' -f2);
do
  trueish "$ENV_DEV" && {
    test -d "$PROJECT_DIR/$(basename "$supportlib")" && {
      script_package_include "$PROJECT_DIR/$(basename "$supportlib")" && break
      $INIT_LOG "error" "" "Error including script-package at $PROJECT_DIR/$(basename "$supportlib")" 1
    }
  }
  for vnd_base in $VND_PATHS
  do
    test -d "$vnd_base/$supportlib" || continue
    script_package_include "$vnd_base/$supportlib" && break
    $INIT_LOG "error" "" "Error including script-package at $vnd_base/$supportlib" 1
  done
done

test -z "${SCRIPTPATH:-}" &&
    $INIT_LOG error "" "No SCRIPTPATH found" ||
    $INIT_LOG note "" "New SCRIPTPATH" "$SCRIPTPATH"
unset supportlib vnd_base lib_path
export SCRIPTPATH

# Sync: U-S:
