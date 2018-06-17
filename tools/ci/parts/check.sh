#!/bin/sh

set -e

# entry-point for CI pre-test phase, to do preflight checks, some verbose debugging
note "Entry for CI pre-test / check phase"


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

bash --version
test -x "$(which dash)" || error "No dash" 12
#test -x "$(which posh)" || error "No posh" 12

not_trueish "$SHIPPABLE" || {
  perl --version
}

composer --version
test -z "$TEST_FEATURE_BIN" || "$TEST_FEATURE_BIN" --version
bats --version
realpath --version
git-versioning version
test -x $(which basher) || error "No basher" 1

not_falseish "$SHIPPABLE" && {
  perl ~/.basher/cellar/bin/tap-to-junit-xml --help || test $? -eq 1
  perl $(which tap-to-junit-xml) --help || test $? -eq 1
}

# Local commands should be on PATH and working OK


note "docker-sh"
{ { docker-sh.sh -V && docker-sh.sh --help
} 2>&1 >/dev/null; } || error "docker-sh"

note "sh-switch"
{ { sh_switch.py -V && sh_switch.py --help
} 2>&1 >/dev/null; } || error "sh_switch"

note "Htd tools"
{ { htd tools
} 2>&1 >/dev/null; } || error "htd tools"

note "Htd prefixes"
{ { htd list-prefixes
} 2>&1 >/dev/null; } || error "htd list-prefixes"

note "box-instance:"
{ {
 box-instance.sh x foo bar && box-instance.sh y
} 2>&1 >/dev/null; } || error "box-instance"


# Other commands in build #dev phase.

set +e
note "Done"
# Id: script-mpe/0.0.4-dev tools/ci/parts/check.sh
