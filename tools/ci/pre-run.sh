#!/bin/sh

. ./tools/sh/env.sh

# entry-point for CI pre-test phase, to do preflight checks, some verbose debugging
note "entry-point for CI pre-test phase"


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

# Local commands should be on PATH and working OK
box version && box -V
box help && box -h && box -h stat
htd version && htd -V
htd help && htd -h && htd -h help
vc.sh version
vc.sh help
radical.py --version
radical.py --help
json.py version && jsotk.py -V
jsotk.py --help
sh_switch.py -V
sh_switch.py --help
match.sh help && match.sh -h && match.sh -h help
matchbox.py help
libcmd_stacked.py -h
radical.py --help && radical.py -vv -h
basename-reg --help

# Local scripts should be the same, but anyway try a few..
./box version
./htd version
./jsotk.py -V
./sh_switch.py -V
./match.sh help && ./match.sh -h && ./match.sh -h help


# More specific scripts that either the build depends on, are are wanted for
# sure. Just in case some parts are not tested properly (yet) make sure they
# run at least.

jsotk.py from-args foo=bar
jsotk.py objectpath \
              $HOME/bin/test/var/jsotk/2.yaml \
              '$.*[@.main is not None]'
htd tools

matchbox.py

match.sh -s var-names

# Other commands in build #dev phase.

