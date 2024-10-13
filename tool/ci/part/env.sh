#!/bin/ash
# See .travis.yml

# XXX: Travis CI: /home/travis/.travis/job_stages: line 1
# Testing deinit.sh to allow better feedback for Shell tool/ and lib DUTs.

export uname=${uname:-$(uname -s)"}

# Set GNU 'aliases' to try to build on Darwin/BSD
export gdate=${gdate:-date}
export ggrep=${ggrep:-grep}
export gsed=${gsed:-sed}
export gawk=${gawk:-awk}
export gstat=${gstat:-stat}
export guniq=${guniq:-uniq}

. "$PWD/tool/sh/part/env-0.sh"

# XXX: cleanup
#set -e
#
#set +o pipefail &&
#set +o errexit &&
#set +o nounset
# Sync: U-S:
