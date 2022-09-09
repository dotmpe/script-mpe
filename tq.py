#!/usr/bin/env python
# Created: 2016-12-16
"""
tq - text-query: simple text character/line+column resolver

Usage
    <EDL> | tq -p FILE
    tq -h
"""
from __future__ import print_function
import os
import sys


parse_span = lambda s: ("Turn %i-%i into integer tuple", tuple([ int(i) - 1 for i in s.split('-') ]))[1]
_1base = lambda t: ("Turn 0-base index into 1-based.", tuple([ i-1 for i in t ]))[1]

if __name__ == '__main__':
    import sys
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)

    elif '-p' in args:
        data = open(args.pop(1)).read()
        edl_d = sys.stdin

        for ref in edl_d.readlines():
            if not ref.strip():
                continue
            print(ref.strip())
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
                print('Description:', data[slice(*_1base(descr_span))])
            elif line_offs_descr_span:
                pass
            elif cmnt_span:
                print('Comment:', data[slice(*_1base(descr_span))])
            elif line_offs_cmnt_span:
                pass
            else:
                print(ref)

    else:
        print("No command-option found", file=sys.stderr)
        sys.exit(1)
