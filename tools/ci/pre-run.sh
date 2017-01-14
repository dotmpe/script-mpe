#!/bin/sh

set -ex

# entry-point for CI pre-test phase, to do preflight checks, some verbose debugging
echo "entry-point for CI pre-test phase"

whoami
hostname

echo "*PATH* env:"
env | grep PATH


echo "Pre-flight check.."

# Basicly if these don't run dont bother testing/building/publishing/...:

composer --version
behat --version

box version && box -V
vc.sh help
radical.py --help
jsotk.py -h
htd help

