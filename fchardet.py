#!/usr/bin/env python
"""Simple frontend for chardet lib

Usage: %(scriptname)s [files | ... ] [--help]

"""
import chardet
#from cllct.osscript_util import dumb_parse_opt


def main(*files):
    if not files or files[0] == '-':
        print chardet.detect(sys.stdin.read())

    else:
        for file in files:
            print "%s:" % (file,),
            print chardet.detect(open(file).read())


if __name__ == '__main__':
    import sys
    sys.exit(main(*sys.argv[1:]))

#    scriptname, args, opts = dumb_parse_opt(sys.argv)
#    if 'help' in opts:
#        print >>sys.stderr, __doc__ % locals()
#    else:


