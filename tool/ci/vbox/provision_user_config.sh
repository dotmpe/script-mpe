#!/usr/bin/env bash

set -e


cd /vagrant

export PATH=$PATH:~/.local/bin
export Build_Deps_Default_Paths=1
./install-dependencies.sh all

#
