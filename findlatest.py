#!/usr/bin/env python
"""
Return the most recent file.

By defaults checks the creation (ie. status update) time.
Using modification time (--mtime) is possible.
"""
import os
import sys

def main():
    argv = sys.argv[1:]
    use = 'ctime'
    latest = 0
    for arg in argv:
        if arg == '--mtime':
            use = arg[2:]
        else:
            assert os.path.exists(arg), arg
            times = {}
            paths = {}
            for root, dirs, files in os.walk(arg):
                for f in files:
                    p = os.path.join(root, f)
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
            print paths[latest]

if __name__ == '__main__':
    main()
