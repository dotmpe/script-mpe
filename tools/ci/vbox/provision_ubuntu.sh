#!/usr/bin/env bash

set -e

apt-get update
apt-get install -y sudo vim git uuid-runtime tidy pv curl wget build-essential python-dev python-yaml
apt-get autoclean
apt-get autoremove

which pip >/dev/null || { cd /tmp/ && { test -e get-pip.py || wget https://bootstrap.pypa.io/get-pip.py; } && python get-pip.py; }

pip uninstall -y zope.interface || printf ""

pip install setuptools pytz twisted sqlalchemy virtualenv PyYAML nose-parameterized objectpath \
  zope.component zope.interface

