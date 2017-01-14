#!/bin/sh

set -e

test ! -d build || rm -rf build
mkdir -vp build

# FIXME: cleanup


run_spec()
{
  R=0
  ( bats --tap test/$spec-spec.bats || R=$? ) | sed 's/^/    /g' > $tmp 2>&1
  test $R -eq 0 && {
    echo "ok $I $spec "
    echo "ok $I $spec " >> $rs
  } || {
    echo "not ok $I $spec (returned $R)"
    echo "not ok $I $spec (returned $R)" >> $rs
    echo $spec >> $failed
  }
  cat $tmp >> $rs
}

#export $(whoami|str_upper)_SKIP=1 $(mkvid $(hostname -s);echo $vid)_SKIP=1
export JENKINS_SKIP=1

tmp=/tmp/test-results.tap
rs=build/test-results.tap
failed=/tmp/failed

I=1
echo "1..24" > $rs

# start with essential tests
for spec in helper util-lib str std os match vc main box-lib box-cmd box
do
  run_spec $spec
  I=$(( $I + 1 ))
done

# in no particular order
test ! -e $failed || rm $failed
for spec in statusdir htd basename-reg dckr diskdoc esop jsotk-py libcmd_stacked matchbox meta mimereg pd radical
do
  run_spec $spec
  I=$(( $I + 1 ))
done


test -e "$failed" && {
  echo "Failed: $(echo $(cat $failed))"
  rm $failed
  unset failed
  exit 1
}



# FIXME: cleanup
#exit 0


var_isset PATH && echo PATH=$PATH || echo no \$PATH
var_isset LIB && echo LIB=$LIB || echo no \$LIB
var_isset SCRIPTPATH && echo SCRIPTPATH=$SCRIPTPATH || echo no \$SCRIPTPATH
var_isset scriptname && echo scriptname=$scriptname || echo no \$scriptname


export PATH=$HOME/.local/bin:$PATH
export LIB=$WORKSPACE
export PATH=$LIB:$PATH

echo TERM=$TERM
#TERM=xterm

# Build_Deps_Default_Paths=1
SRC_PREFIX=$HOME/build PREFIX=$HOME/.local \
	./install-dependencies.sh '*'


./htd version
./htd help
./box help

htd version
box version

#export Build_Deps_Default_Paths=1
#./install-dependencies.sh test

bats --version

#    rm -rf $HOME/bin
#    ln -s $WORKSPACE $HOME/bin
#    export JTB_HOME=$HOME/build/jtb

export PREFIX=
export TRAVIS_SKIP=1
export JENKINS_SKIP=1
export PYTHONPATH=$PYTHONPATH:$HOME/lib/py

mkdir -vp ./build




test_bats()
{
  test -n "$SUITE" && {{
    SPECS=
    for SPEC in $SUITE
    do
      SPECS="$SPECS ./test/$SPEC-spec.bats"
    done
  }} || test -n "$SPEC" && {{
    SPECS="./test/$SPEC-spec.bats"
  }} || {{
    SPECS=./test/*-spec.bats
  }}

  bats $SPECS || exit 0 > ./build/bats-test-results.tap
}


test_features()
{
  ./bin/behat --tags '~@todo&&~@skip'
}


test_shell
test_features

