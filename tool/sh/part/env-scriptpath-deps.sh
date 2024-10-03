#!/bin/sh

# Add script-packages (from dependencies.txt) to SCRIPTPATH

test -n "${INIT_LOG-}" || return 109

test -z "${SCRIPTPATH-}" ||
  $INIT_LOG "note" "env-scriptpath-deps" "Current SCRIPTPATH" "$SCRIPTPATH"

for func_dep in fnmatch trueish remove_dupes unique_paths script_package_include
do test "$(type -t $func_dep 2>/dev/null)" = function && continue
  . $U_S/tools/sh/parts/${func_dep//_/-}.sh
done

test -n "${SH_EXT-}" || {
  test -n "${REAL_SHELL-}" ||
    REAL_SHELL=$(ps --pid $$ --format cmd --no-headers | cut -d' ' -f1)
  fnmatch "-*" "$REAL_SHELL" &&
    SH_EXT="${REAL_SHELL:1}" || SH_EXT=$(basename -- "$REAL_SHELL")
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

test -n "${PROJECT_DEPS:-}" || PROJECT_DEPS=$CWD/dependencies.txt

# Look for deps at each VND_PATHS, source load.*sh file to let it setup SCRIPTPATH
for supportlib in $(grep -h '^\(git\|dir\|basher\) ' $PROJECT_DEPS | cut -d' ' -f2);
do
  fnmatch "[/~]*" "$supportlib" && {
    supportlib="$(eval "echo $supportlib")"

    test -d "$supportlib" && {
      script_package_include "$supportlib" && continue
      $INIT_LOG "error" "" "Error including script-package at" "$supportlib"
      continue
    }
  }

  # Override VND_PATHS in Dev-Mode with basenames from ~/project that match
  # dependency basename
  trueish "${ENV_DEV-}" && {
    test -d "$PROJECT_DIR/$(basename "$supportlib")" && {
      script_package_include "$PROJECT_DIR/$(basename "$supportlib")" && continue
      $INIT_LOG "error" "" "Error including script-package at" "$PROJECT_DIR/$(basename "$supportlib")" 31
      continue
    }
  }

  # Go over known locations and include user-script packages matching dependency
  for vnd_base in $VND_PATHS
  do
    test -d "$vnd_base/$supportlib" || continue
    test "$vnd_base/$supportlib/*" != "$(echo "$vnd_base/$supportlib/"*)" ||
      continue

    script_package_include "$vnd_base/$supportlib" && break
    $INIT_LOG "error" "" "Error including script-package at" "$vnd_base/$supportlib" 32
    break
  done

  true
done

script_package_include $CWD ||
  $INIT_LOG "error" "" "Error including script-package at" "$CWD" 30

test -z "${SCRIPTPATH:-}" &&
    $INIT_LOG "error" "" "No SCRIPTPATH found" ||
    $INIT_LOG "note" "" "New SCRIPTPATH from $PROJECT_DEPS" "$SCRIPTPATH"
unset supportlib vnd_base
export SCRIPTPATH

# Sync: U-S:
