#!/usr/bin/env make.sh

set -e


version=0.0.4-dev # script-mpe


x_test__version()
{
  echo $version
}
x_test___V() { x_test__version; }
x_test____version() { x_test__version; }


x_test__test()
{
  echo Ack.
}


## Main parts

main_env \
INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std box" \\
INIT_LIB="\$default_lib str str-htd logger-theme match main std stdio sys os box src src-htd"

main_local \\
subcmd_default=version subcmd_func_pref
# ; subcmd_func_pref=\${base}__ \\

main_load_epilogue \
# Id: script-mpe/0.0.4-dev x-test-make-preproc.sh
