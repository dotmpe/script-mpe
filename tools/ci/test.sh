#!/bin/sh

set -e

. ./tools/sh/env.sh
. ./util.sh
. ./main.lib.sh



test_shell()
{
  test -n "$SUITE" && {
    SPECS=
    for SPEC in $SUITE
    do
      SPECS="$SPECS ./test/$SPEC-spec.bats"
    done
  } || test -n "$SPEC" && {
    SPECS="./test/$SPEC-spec.bats"
  } || {
    SPECS=./test/*-spec.bats
  }
  bats $SPECS || return $? > ./build/bats-test-results.tap
}


test_features()
{
  behat --tags '~@todo&&~@skip&&~@skip.travis'
}


run_spec()
{
  R=0
  ( bats --tap test/$spec-spec.bats || R=$? ) | sed 's/^/    /g' > $tmp 2>&1
  test $R -eq 0 && {
    echo "ok $I $spec "
    echo "ok $I $spec " >> $TEST_RESULTS
  } || {
    echo "not ok $I $spec (returned $R)"
    echo "not ok $I $spec (returned $R)" >> $TEST_RESULTS
    echo $spec >> $failed
  }
  cat $tmp >> $TEST_RESULTS
}



note "entry-point for CI test phase"


test ! -d build || rm -rf build
mkdir -vp build

var_isset PATH && echo PATH=$PATH || echo no \$PATH
var_isset LIB && echo LIB=$LIB || echo no \$LIB
var_isset SCRIPTPATH && echo SCRIPTPATH=$SCRIPTPATH || echo no \$SCRIPTPATH
var_isset scriptname && echo scriptname=$scriptname || echo no \$scriptname


#export LIB=$WORKSPACE
#export PATH=$LIB:$PATH
#    rm -rf $HOME/bin
#    ln -s $WORKSPACE $HOME/bin
#    export JTB_HOME=$HOME/build/jtb
#export PREFIX=
#export TRAVIS_SKIP=1
#export JENKINS_SKIP=1
#export $(whoami|str_upper)_SKIP=1 $(mkvid $(hostname -s);echo $vid)_SKIP=1
#export JENKINS_SKIP=1


test -n "$Build_Deps_Default_Paths" || {
  export Build_Deps_Default_Paths=1
}
./install-dependencies.sh test


tmp=/tmp/test-results.tap
test -n "$TEST_RESULTS" || TEST_RESULTS=build/test-results.tap
failed=/tmp/failed

I=1
echo "1..24" > $TEST_RESULTS

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

tap-to-junit-xml $TEST_RESULTS $(dirname $TEST_RESULTS)/$(basename $TEST_RESULTS .tap).xml

# FIXME: test everything eventually. But for now only require specific specs
# above.
test_shell || {
  warn "Complete test set failed"
}

test_features

