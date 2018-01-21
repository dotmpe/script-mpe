#!/usr/bin/env python
"""Simple frontend for chardet lib

"""
from __future__ import print_function
import chardet
#from cllct.oslibcmd_docopt import dumb_parse_opt
__usage__ = """
Usage: %(scriptname)s [files | ... ] [--help]
""" % dict(scriptname=__file__)#'fchardet.py')

def main(*files):
    if '-h' in files:
        print(__usage__)
        return 1
    if not files or files[0] == '-':
        print(chardet.detect(sys.stdin.read()))

    else:
        for file in files:
            print("%s:" % (file,),end='')
            print(chardet.detect(open(file).read()))


if __name__ == '__main__':
    import sys
#    scriptname, args, opts = dumb_parse_opt(sys.argv)
#    if 'help' in opts:
#        print >>sys.stderr, __doc__ % locals()
#    else:
    sys.exit(main(*sys.argv[1:]))
