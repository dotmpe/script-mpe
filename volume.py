#!/usr/bin/env python
"""
"""
__description__ = "volume - "
__version__ = '0.0.2-dev' # script-mpe
__db__ = '~/.volume.sqlite'
__usage__ = """
Usage:
  volume.py [options] [ARGS]
  volume.py -h|--help
  volume.py --version

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    --config NAME
                  Config [default: cllct.rc]

Other flags:
    -v            Increase verbosity.
    -h --help     Show this usage description. For a command and argument
                  description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__, )
from __future__ import print_function
import os
import sys
from pprint import pprint

import lib
import confparse
import taxus
import libcmd_docopt
from libname import Namespace, Name
from libcmdng import Targets, Arguments, Keywords, Options,\
    Target, TargetResolver



NS = Namespace.register(
        prefix='vol',
        uriref='http://project.dotmpe.com/script/#/cmdline.Volume'
    )

Options.register(NS,
    )



@Target.register(NS, 'find-volume', 'txs:pwd')
def find_volume(opts=None, pwd=None):
    vdb = None
    print(list(confparse.find_config_path("git", pwd.location.path)))
    for path in confparse.find_config_path("cllct", pwd.location.path):
        vdb = os.path.join(path, 'volume.db')
        if os.path.exists(vdb):
            break
    if not vdb:
        if opts.init:
            pass
    print(vdb)
    yield vdb


def oldmain():
    # XXX: cleanup all oldmain
    import txs, cmdline
    print(TargetResolver().main(['vol:find-volume']))
    #TargetResolver().main(['cmd:options'])


def main(argv, doc=__doc__, usage=__usage__):

    """
    Execute using docopt-mpe options.
    """

    # Process environment
    db = os.getenv( 'VOLUME_DB', __db__ )
    if db is not __db__:
        usage = usage.replace(__db__, db)
    opts = libcmd_docopt.get_opts(doc + usage, version=get_version(), argv=argv[1:])
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)

    # Load configuration
    config_file = list(confparse.expand_config_path(opts.flags.config)).pop()
    settings = confparse.load_path(config_file)

    pprint(settings.todict())
    print
    for v, p in settings.volume.items():
        print(v, p)
    print
    for v, s in settings.volumes.items():
        print(v, s)


def get_version():
    return 'volume.mpe/%s' % __version__


if __name__ == '__main__':
    oldmain()
    #sys.exit(main(sys.argv))
