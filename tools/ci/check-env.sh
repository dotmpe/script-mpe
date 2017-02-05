#!/bin/sh

note "Checking build parameterisation.."

case "$(basename $TEST_SHELL)" in
  sh|dash|posh|bash ) ;;
  * ) error "Missing/Unknown TEST-SHELL '$TEST_SHELL'" ;;
esac

note "Done"

