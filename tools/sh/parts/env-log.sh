#!/bin/sh

. "$script_util/parts/env-log-reinit.sh" ||
    $INIT_LOG "error" "" "Failed env-part" "$? log-reinit"

. "$script_util/parts/env-init-log.sh" ||
    $INIT_LOG "error" "" "Failed env-part" "$? init-log"
#
