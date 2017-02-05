#!/bin/bash
find . -type l ! -exec test -e {} \; -print

