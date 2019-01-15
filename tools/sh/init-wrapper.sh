#!/bin/sh

test -n "$U_S" -a -d "$U_S" || source "$(dirname "$0")/parts/env-0-u_s.sh"
test -n "$U_S" -a -d "$U_S" || return

# Dev-Module for lib_loadXXX: cli wrapper, see init.sh
. $U_S/src/sh/lib/lib.lib.sh


lib_lib_load()
{
  test -n "$default_lib" ||
      default_lib="os std sys str log shell stdio src main argv match vc std-ht"
}


. $U_S/src/sh/lib/lib-util.lib.sh


# Main

# XXX: @Spec @Htd util-mode
# ext: external, sourced file gets to do everything. Here simply return.
# lib: set to try to load the default-lib required, but fail on missing envs
# boot: setup env, then load default-lib

case "$0" in

  "-"*|"" ) ;;

  * )

      test -n "$f_lib_load" && {
        # never
        echo "util.sh assert failed: f-lib-load is set ($0: $*)" >&2
        exit 1

      } || {

        # Set util_mode before sourcing util.sh to do anything else
        test -n "$util_mode" || util_mode=ext
      }

      # Return now for 'ext'
      test "$util_mode" = "ext" && return

      # XXX: for logger
      export scriptname base

      # Or either start given mode
      case "$util_mode" in
        boot|lib )
            lib_lib_load || return

      # Or return errstat on first unmatched case (or errors per step).
      esac || return

      case "$util_mode" in
        boot )
            lib_util_init || return ;;
      esac

      case "$util_mode" in
        boot|lib )
            lib_lib_init || return
            lib_load $default_lib || return ;;
      esac

      case "$util_mode" in
        boot )
            lib_init || return
            lib_util_deinit || return ;;
      esac
    ;;
esac

# Sync: U-S:tools/sh/init-wrapper.sh
# Id: script-mpe/0.0.4-dev tools/sh/init-wrapper.sh
