#!/bin/sh

set -xe

. ./tools/sh/env.sh

# entry-point for CI pre-test phase, to do preflight checks, some verbose debugging
note "entry-point for CI pre-test / check phase"


note "User: $( whoami )"
note "Host: $( hostname )"

note "*PATH* env:"
env | grep PATH

note "TERM=$TERM"
note "TRAVIS_SKIP=$TRAVIS_SKIP"
note "ENV=$ENV"
note "Build dir: $(pwd)"


note "Pre-flight check.."

# Basicly if these don't run dont bother testing/building/publishing/...:

# External commands
composer --version
behat --version
bats --version
realpath --version
basher version

cpan install XML::Generator
~/.basher/bin/tap-to-junit-xml --help
tap-to-junit-xml --help

# Local commands should be on PATH and working OK
note "Box:" && box version && box -V
note "Box:" && box help && box -h && box -h stat
note "Htd:" && htd version && htd -V
note "Htd:" && htd help && htd -h && htd -h help
note "Vc:" && vc.sh version
note "Vc:" && vc.sh help
note "Rad:" && radical.py --version
note "Rad:" && radical.py --help
note "Rad:" && radical.py --help && radical.py -vv -h
note "jsotk.py:" && jsotk.py version && jsotk.py -V
note "jsotk.py:" && jsotk.py --help
note "sh-switch" && sh_switch.py -V
note "sh-switch" && sh_switch.py --help
note "match" && match.sh help && match.sh -h && match.sh -h help
note "matchbox" && matchbox.py help
note "libcmd-stacked" && libcmd_stacked.py -h
note "basename-reg" && basename-reg --help

# Local scripts should be the same, but anyway try a few..
./box version
./htd version
./jsotk.py -V
./sh_switch.py -V
./match.sh help && ./match.sh -h && ./match.sh -h help


# More specific scripts that either the build depends on, are are wanted for
# sure. Just in case some parts are not tested properly (yet) make sure they
# run at least.

note "jsotk"
jsotk.py from-args foo=bar
jsotk.py objectpath \
              $HOME/bin/test/var/jsotk/2.yaml \
              '$.*[@.main is not None]'

note "Htd tools"
htd tools

note "matchbox.py default"
matchbox.py

note "match -s var-names"
match.sh -s var-names

note "box-instance:"
box-instance x foo bar
box-instance y


# Other commands in build #dev phase.

