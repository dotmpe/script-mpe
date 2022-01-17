#!/usr/bin/env python
"""
Give a file count for every directory below current path.
"""
from __future__ import print_function
import os, sys


def main(pwd):
    dir_length = {}

    for root, dirs, files in os.walk(pwd):

        count = len( dirs + files )

        assert root not in dir_length
        dir_length[root] = count

    def upward(path):
        parts = path.split(os.sep)
        while parts:
            parts.pop()
            if parts:
                yield os.sep.join(parts)

    for path in dir_length.keys():
        for sup in upward(path):
            if sup not in dir_length:
                dir_length[sup] = 0
            dir_length[sup] += dir_length[path]

    sorted = {}
    for root in dir_length.keys():
        count = dir_length[root]
        if count not in sorted:
            sorted[count] = []
        sorted[count].append(root)

    values = list(sorted.keys())
    values.sort()
    width = len(str(values[-1])) + 1
    for count in values:
        print(("%#0"+str(width)+"s\t%s") % (count, ("\n"+(width*' ')+"\t").join(sorted[count])))


if __name__ == '__main__':
    args = sys.argv[1:]
    if '-h' in args or ( len(args) and not sys.path.exists( args[0] )):
        print(__doc__)
        sys.exit(0)
    main( sys.argv[1:] or '.' )
