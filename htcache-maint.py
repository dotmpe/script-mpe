#!/usr/bin/env python
"""
:Created: 2012-03-02

htcache-maint [TODO]
    - prune files
        - except some domains/netpaths, tocache
        - except files >11M
    - checksum all resources..
    - de-dupe by symlinking
htcache
    - Drop: drop known entertainment and advertising
    - NoCache: to keep certain request from being cached
    - Sort: to rewrite between URI namespaces [TODO]
    - Reset: to reload aux files
    - Static r/o mode while importing checksums? [XXX]
    - Prune metadata for non-existent files [TODO]

"""
from __future__ import print_function
import os
from os.path import join, isfile, islink

import lib


HTDIR = '/var/cache/www/'

def check():
    for root, dirs, files in os.walk(HTDIR):
        for fname in files:
            fpath = os.path.join(root, fname)
            if isfile(fpath) and not islink(fpath):
                print(lib.get_checksum_sub(fpath))

def main():
    check()

if __name__ == '__main__':
    main()
