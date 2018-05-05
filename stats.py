#!/usr/bin/env python
"""stats -
:created: 2017-12-08
"""
from __future__ import print_function

__version__ = '0.0.4-dev' # script-mpe
__stats_db__ = '~/.taxus-stats.sqlite'
__usage__ = """

Usage:
  stats.py [options] ( stats | list )
  stats.py -h|--help|help
  stats.py --version

Options:
    -f STATS, --file=STATS
                  Work on specified YAML stats file. Default is to look for name
                  in nearest workspace metadir [default: stats.yml]
    -d REF, --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    --no-db       ..
    -y, --yes     ..
    -s, --strict  ..
    -q, --quiet   Quiet operations
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __stats_db__, __version__ )
__doc__ += __usage__

from script_mpe import confparse, libcmd_docopt, taxus, log
from libcmd_docopt import cmd_help
from taxus import Taxus, ScriptMixin


### A few more globals

ctx = Taxus()

cmd_default_settings = dict( quiet=False )


### CLI Subcommands

def cmd_stats(g, opts):
    """
    """
    global ctx
    sa = ctx.sa_session
    doc, statsdoc = None, None
    if not g.file:
        ws = Workdir.fetch()
        if ws:
            statsdoc = ws.statsdoc
        else:
            return 1
    pass


def cmd_list(g, opts):
    """
    """
    global ctx
    sa = ctx.sa_session


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    opts.flags.update(ctx.settings)
    opts.flags.update(
        dbref = ScriptMixin.assert_dbref(opts.flags['dbref'])
    )
    return init

def main(opts):

    """
    Execute command.
    """
    global ctx, commands

    ctx.settings = settings = opts.flags

    if not settings.no_db:
        assert settings.dbref
        ctx.session = 'default'
        ctx.setmetadata(None)
        ctx.init(settings.dbref)

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    global __version__
    return '%s' % __version__


if __name__ == '__main__':
    import sys
    argv = sys.argv[1:]
    if not argv: argv = [ 'list' ]
    opts = libcmd_docopt.get_opts(__doc__, version=get_version(), argv=argv,
            defaults=defaults)
    sys.exit(main(opts))
