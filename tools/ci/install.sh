#!/bin/bash

set -ex

# entry-point for CI install phase
echo "entry-point for CI install phase"


pip install --upgrade --user -r requirements.txt
pip install --upgrade --user -r test-requirements.txt
npm install parse-torrent lodash
./install-dependencies.sh all
pip install --user nose-parameterized
mkdir -vp ~/.local/{bin,lib,share}

