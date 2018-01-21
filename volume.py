#!/usr/bin/env python
"""volume.py

"""
from __future__ import print_function
__description__ = "volume - "
__version__ = '0.0.4-dev' # script-mpe
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
import os
import sys
from pprint import pprint

from script_mpe import lib
from script_mpe import confparse
from script_mpe import taxus
from script_mpe import libcmd_docopt
from script_mpe.libname import Namespace, Name
from script_mpe.libcmdng import Targets, Arguments, Keywords, Options,\
    Target, TargetResolver



NS = Namespace.register(
        prefix='vol',
        uriref='http://project.wtwta.org/script/#/cmdline.Volume'
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
    from script_mpe import txs, cmdline
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
    import sys
    args = sys.argv[1:]
    if '-h' in args:
            print(__doc__)
            sys.exit(0)

    oldmain()
    #sys.exit(main(sys.argv))
