#!/bin/sh

# entry-point for CI pre-test phase, to do preflight checks, some verbose debugging

sh_include init

check-all()
{
  true
}

not_trueish "$SHIPPABLE" || {
  perl --version
}

test -z "${TEST_FEATURE_BIN:-}" || "$TEST_FEATURE_BIN" --version
bats --version
realpath --version

basher help >/dev/null
test -x $(which basher) || $LOG error "" "No basher" 1

git-versioning check

travis version && {
  test -n "GITHUB_TOKEN" || $LOG error "" "Empty GITHUB_TOKEN" 1
  travis login --github-token "$GITHUB_TOKEN" &&
    travis history -r dotmpe/script-mpe
}


#not_falseish "$SHIPPABLE" && {
#
#  perl ~/.basher/cellar/bin/tap-to-junit-xml --help || test $? -eq 1
#
#  perl $(which tap-to-junit-xml) --help || test $? -eq 1
#}

# Local commands should be on PATH and working OK


$LOG note "" "docker-sh"
{ { docker-sh.sh -V && docker-sh.sh --help
} 2>&1 >/dev/null; } || $LOG error "" "docker-sh"

$LOG note "" "sh-switch"
{ { sh_switch.py -V && sh_switch.py --help
} 2>&1 >/dev/null; } || $LOG error "" "sh_switch"

$LOG note "" "matchbox"
{ { matchbox.py -V && matchbox.py --help
} 2>&1 >/dev/null; } || $LOG error "" "matchbox"

$LOG note "" "Htd tools"
{ { htd tools
} 2>&1 >/dev/null; } || $LOG error "" "htd tools"

$LOG note "" "Htd prefixes"
{ { htd list-prefixes
} 2>&1 >/dev/null; } || $LOG error "" "htd list-prefixes"

$LOG note "" "box-instance:"
{ {
 box-instance.sh x foo bar && box-instance.sh y
} 2>&1 >/dev/null; } || $LOG error "" "box-instance"



$LOG note "$scriptname:$stage:check" "Done"
# Sync: U-S:
# Id: script-mpe/0.0.4-dev tools/ci/parts/check.sh
