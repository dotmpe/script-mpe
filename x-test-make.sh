#!/usr/bin/env make.sh

version=0.0.4-dev # script-mpe


main_xtest_default=version


x_test__test()
{
  echo Ack.
}


## Main parts

main-bases X-Test-Make X-Test Main Std
main-init-env INIT_ENV="0-std" \
INIT_LIB="\$default_lib ctx-std ctx-main"
main-epilogue \
# Id: script-mpe/0.0.4-dev x-test-make.sh ex:ft=bash:
