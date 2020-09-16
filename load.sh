#!/bin/sh

$INIT_LOG "note" "" "Adding SCRIPTPATH" "$(dirname "$SCRIPT_SOURCE")"
SCRIPTPATH="${SCRIPTPATH-}${SCRIPTPATH:+":"}$(dirname "$SCRIPT_SOURCE")"
SCRIPTPATH="$SCRIPTPATH:$(dirname "$SCRIPT_SOURCE")/commands"
SCRIPTPATH="$SCRIPTPATH:$(dirname "$SCRIPT_SOURCE")/contexts"
