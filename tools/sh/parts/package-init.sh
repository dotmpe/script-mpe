#!/usr/bin/env bash

# request load, or require
package_req ()
{
  package_require=true package_require
}

package_require ()
{
  package_load || return

  # Evaluate package env, if found or required
  test ! -e "${PACK_SH-}" &&
  ! "${package_require:-false}" || {

    . $PACK_SH || stderr error "local package ($?)" 7
    $LOG debug "" "Found package '$package_id'"
  }
}

# setup env XXX: may be deprecated by now
package_load ()
{
  test ${package_lib_init:-1} -eq 0 || {
    test ${package_lib_load:-1} -eq 0 || {
      lib_require package || return
    }
    package_lib_auto=true lib_init package || return
  }
  package_init
}

#
