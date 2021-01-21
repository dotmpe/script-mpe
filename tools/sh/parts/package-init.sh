#!/usr/bin/env bash

# request load, or require
package_req ()
{
  package_require=0 package_require
}

package_require ()
{
  package_load || return

  # Evaluate package env
  test ! -e "$PACK_SH" -a ${package_require:-1} -eq 0 || {

    . $PACK_SH || stderr error "local package ($?)" 7
    $LOG debug "" "Found package '$package_id'"
  }
}

# setup env
package_load ()
{
  test ${package_lib_init:-1} -eq 0 || {
    test ${package_lib_loaded:-1} -eq 0 || {
      lib_require package || return
    }
    package_lib_auto=0 lib_init package || return
  }
  package_init
}

#
