#!/usr/bin/env bash

for x in composer.lock .Gemfile.lock
do
  test -e .htd/$x || continue
  rsync -avzui .htd/$x $x
done

# Sync: U-S:
