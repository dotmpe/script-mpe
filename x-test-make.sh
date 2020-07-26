#!/usr/bin/env make.sh

version=0.0.4-dev # script-mpe


main_xtest_default=version

xtest__version()
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

main-bases x-test-make X-Test @Std
main-env INIT_ENV="0-std"
main-epilogue \
# Id: script-mpe/0.0.4-dev x-test-make.sh ex:ft=bash:
