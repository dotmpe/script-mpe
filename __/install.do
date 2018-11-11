#!/bin/sh

set -e


redo-always
redo-ifchange ../requirements.txt
redo-ifchange ../package.json

pip install -r ../requirements.txt

( NODE_ENV=development && cd .. && npm install )
