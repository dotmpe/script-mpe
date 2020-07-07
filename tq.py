#!/usr/bin/env python
"""
tq - text-query: simple text character/line+column resolver
"""
from __future__ import print_function
import os
import sys


def parse_span(s):
    return tuple([ int(i) - 1 for i in s.split('-') ])


if __name__ == '__main__':
    import sys
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)
        sys.exit(0)

    data = open(args.pop(0)).read()

    edl_d = sys.stdin

    for ref in edl_d.readlines():

        if not ref.strip():
            continue

        ref_ = ref.split(':')
        prefix, file, line_span, descr_span, line_offs_descr_span, cmnt_span, line_offs_cmnt_span = ref_[:7]

        line_span = parse_span(line_span)
        if descr_span:
            descr_span = parse_span(descr_span)
        if line_offs_descr_span:
            line_offs_descr_span = parse_span(line_offs_descr_span)
        if cmnt_span:
            cmnt_span = parse_span(cmnt_span)
        if line_offs_cmnt_span:
            line_offs_cmnt_span = parse_span(line_offs_cmnt_span)

        if descr_span:
            print('Description:', data[slice(*[ i-1 for i in descr_span ])])
        elif line_offs_descr_span:
            pass
        elif cmnt_span:
            print('Comment:', data[slice(*[ i-1 for i in descr_span ])])
        elif line_offs_cmnt_span:
            pass
        else:
            print(ref)
