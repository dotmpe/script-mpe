#!/bin/sh

. ./tools/sh/env.sh

# entry-point for CI pre-test phase, to do preflight checks, some verbose debugging
echo "entry-point for CI pre-test phase"


whoami
hostname

echo "*PATH* env:"
env | grep PATH

echo TERM=$TERM

echo "TRAVIS_SKIP=$TRAVIS_SKIP"
echo "ENV=$ENV"
echo "Build dir: $(pwd)"


echo "Pre-flight check.."

# Basicly if these don't run dont bother testing/building/publishing/...:

composer --version
behat --version
bats --version

box version && box -V
box help
htd version && htd -V
htd help && htd -h
vc.sh version
vc.sh help
radical.py --version
radical.py --help
json.py version && jsotk.py -V
jsotk.py --help
sh_switch.py -V
sh_switch.py --help

./box version
./htd version
./jsotk.py -V
./sh_switch.py -V


# FIXME: "Something wrong with pd/std__help"
#projectdir.sh help

jsotk.py from-args foo=bar
jsotk.py objectpath \
      $HOME/bin/test/var/jsotk/2.yaml \
      '$.*[@.main is not None]'

#htd script
htd tools
htd install json-spec

