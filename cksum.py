#!/usr/bin/env python
"""
"""
from __future__ import print_function
__description__ = "cksum.py - "
__version__ = '0.0.4-dev' # script-mpe

from script_mpe.libhtd import *
from script_mpe.res.ck import *

__algos__ = file_resolvers.keys()
__default_algo__ = "ck"
__usage__ = """
Usage:
  cksum.py [-v... options] [ FILES... | calc FILES... ]
  cksum.py [-v... options] check TABLE
  cksum.py -h|--help
  cksum.py help [CMD]
  cksum.py --version

Options:
  -a ALGO, --algorithm ALGO
                 Calculate one of available checkum algorithms:
                 %s [default: %s]
  -F FMT, --format FMT
                 TODO: see tlit cksum
  --format-from MEDIATYPE
                 TODO: see tlit cksum
  --verbose, -v  ..
  --quiet        ..
  -h --help      Show this usage description
  --version      Show version (%s)
""" % ( ",".join(__algos__), __default_algo__, __version__, )
import os
from itertools import chain


# CRC32 output includes size and is single space separated, iso. double space
# as with other algos
cksums = algos_crc32b + algos_crc32_cksum_unix + algos_crc32_ethernet

def cmd_calc(FILES, opts):
    num = len(FILES)
    algo = opts.flags.algorithm
    for fname in FILES:
        if algo in cksums:
            cksum, size = file_resolvers[algo](fname)
            print( "%d %d %s" % (cksum, size, fname))
        else:
            cksum = file_resolvers[algo](fname)
            if num > 1:
                print( "%s  %s" % (cksum, fname))
            else:
                print(cksum)

def cmd_check(TABLE):
    for t in TABLE:
        print(t)


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug
    ))

### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    libcmd_docopt.defaults(opts)
    return init

def main(opts):
    opts.default = 'calc'
    settings = opts.flags
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    global __version__
    return 'script-mpe:cksum.py/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    usage = __description__ +'\n\n'+ __usage__
    opts = libcmd_docopt.get_opts(
            usage, version=get_version(), defaults=defaults)
    sys.exit(main(opts))
