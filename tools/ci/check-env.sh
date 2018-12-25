#!/bin/sh

$LOG note "" "Checking build parameterisation.."

case "$(basename $TEST_SHELL)" in
  sh|dash|posh|bash ) ;;
  * ) $LOG error "" "Missing/Unknown TEST-SHELL '$TEST_SHELL'" ;;
esac

$LOG note "" "Done"
