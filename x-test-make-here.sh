#!/usr/bin/env make.sh
set -eu


version=0.0.4-dev # script-mpe


x_test__test()
{
  echo Ack.
}


## Main parts

MAKE-HERE
INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std box" \
INIT_LIB="\\$default_lib str str-htd logger-theme match main std stdio sys os box src src-htd ctx-std ctx-main"

main-local
subcmd_default=version

main-bases
x-test main std

main-epilogue
# Id: script-mpe/0.0.4-dev x-test-make-here.sh
