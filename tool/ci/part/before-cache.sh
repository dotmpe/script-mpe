#!/bin/sh

cp $HOME/.docker/config.json /tmp/docker-config.json
rm -f \
    $HOME/.docker/config.json \
    $HOME/.cache/pip/log/debug.log \
    $HOME/.npm/anonymous-cli-metrics.json

# Sync: U-S:
