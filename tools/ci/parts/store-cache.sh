#!/usr/bin/env bash
for x in composer.lock .Gemfile.lock
do
  test -e $x || continue
  rsync -avzui $x .htd/$x
done
# Sync: U-S:
