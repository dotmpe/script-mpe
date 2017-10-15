#!/usr/bin/env python
"""
Return the most recent file.

By defaults checks the creation (ie. status update) time.
Using modification time (--mtime) is possible.
"""
from __future__ import print_function
import os
import sys
from lib import is_versioned


def main():
    argv = sys.argv[1:]
    use = 'ctime'
    print_ts = False
    latest = 0
    for arg in argv:
        if arg == '--mtime':
            use = arg[2:]
        elif arg == '--print-timestamp':
            print_ts = True
        #elif arg == '--ignore-rcs': # XXX: default only, no settings for ignore-rcs
        #    ignore_rcs_path = arg[2:]
        else:
            assert os.path.exists(arg), arg
            assert os.path.isdir(arg), arg
            times = {}
            paths = {}
            if is_versioned(arg):
                return
            for root, dirs, files in os.walk(arg):
                for d in dirs:
                    rmdirs = []
                    for d in dirs:
                        p = os.path.join(root, d)
                        if is_versioned(p):
                            rmdirs.append(d)
                    for d in rmdirs:
                        dirs.remove(d)
                for f in files:
                    p = os.path.join(root, f)
                    if not os.path.exists(p):
                        continue
                    if use == 'mtime':
                        timestamp = os.path.getmtime(p)
                    elif use == 'atime':
                        timestamp = os.path.getatime(p)
                    elif use == 'ctime':
                        timestamp = os.path.getctime(p)
                    paths[timestamp] = p
                    times[p] = timestamp
                    if latest < timestamp:
                        latest = timestamp
            if print_ts:
                print(latest, paths[latest])
            else:
                print(paths[latest])

if __name__ == '__main__':
    main()
