#!/bin/sh

set -e

test -n "$VBOX_HOSTNAME" || export VBOX_HOSTNAME=$(hostname)

