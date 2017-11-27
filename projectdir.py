#!/usr/bin/env python
"""projectdir -
:created: 2017-11-23
"""
from __future__ import print_function

__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.taxus-code.sqlite'
__usage__ = """

Usage:
  project.py [options] ( [ find ] [ <refs>... ] )
  project.py [options] stat [ <refs>... ]

Options:
    --ignored
                  Include ignored/excluded files in output.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__ )
__doc__ += __usage__

import libcmd_docopt
import log
from libcmd_docopt import cmd_help
from taxus import Taxus, v0, ScriptMixin
from taxus.init import SqlBase, get_session
from res import Workdir, Repo
from taxus.v0 import Node, Topic, Host, Project, VersionControl


models = [ Project, VersionControl ]
context = Taxus(version='projectdir')


def cmd_list(refs, settings):

    """
    List versioned dirs.
    """

    ws = Workdir.fetch()
    if ws:
        ws.find_scmdirs()


def cmd_find(refs, settings):

    """
    List untracked files. Use --ignored to include ignored files.

    TODO: clean Workdir().find_untracked API, flexible backends.
    Ie. match symlinks.tab entries.
    """

    ws = Workdir.fetch()
    if ws:
        if settings.ignored:
            ws.find_excluded()
        else:
            ws.find_untracked()

    else:
        repo = Repo.fetch()
        if settings.ignored:
            for p in repo.excluded():
                print(p)
        else:
            for p in repo.untracked():
                print(p)


def cmd_stat(refs, settings):

    """
    TODO: list dirty files.
    """


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'find'
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'project.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__doc__, version=get_version())
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
