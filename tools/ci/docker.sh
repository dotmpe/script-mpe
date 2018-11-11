#!/bin/sh

set -e

cd /tmp/
git clone http://github.com/bvberkum/script-mpe
cd script-mpe
git checkout features/docker-ci

export CS=dark TMPDIR=$TMP

redo __/install
redo __/test
redo .cllct/__required__
