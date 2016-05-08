#!/bin/sh


export $(whoami|str_upper)_SKIP=1 $(mkvid $(hostname -s);echo $vid)_SKIP=1
# start with essential tests
for spec in helper util-lib str std os match vc main box-lib box-cmd box
do
  bats test/$spec-spec.bats || exit $?
done

# in no particular order
failed=/tmp/failed
test ! -e $failed || rm $failed
for spec in statusdir htd basename-reg dckr diskdoc esop jsotk-py libcmd_stacked matchbox meta mimereg pd radical
do
  bats test/$spec-spec.bats || echo $spec >> $failed
done

test -e "$failed" && {
  echo "Failed: $(echo $(cat $failed))"
  rm $failed
  unset failed
  exit 1
}
exit 0


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
export PYTHON_PATH=$PYTHON_PATH:$HOME/lib/py

mkdir -vp ./build

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

bats $SPECS || exit 0 > ./build/test-results.tap



            export PATH=$PATH:$HOME/usr/bin/
            bats --version

            rm -rf $HOME/bin
            ln -s $WORKSPACE $HOME/bin
            export PATH=$PATH:$HOME/bin/
            export PYTHON_PATH=$PYTHON_PATH:$HOME/lib/py
            export JTB_HOME=$HOME/build/jtb

            export PREFIX=$WORKSPACE
            export TRAVIS_SKIP=1
            export JENKINS_SKIP=1
            ./box help
            bash -c './test/{bats-tests}-spec.bats'

