#!/usr/bin/env python
"""
:Created: 2017-08-13

Commands:
  - list
  - couch (list)
  - memdebug
  - help [CMD]

  Database:
    - info | init | stats | clear
"""
from __future__ import print_function
__description__ = "uris - "
__short_description__ = "..."
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.bookmarks.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """
Usage:
  uris.py [-v... options] (list) [NAME]
  uris.py [-v... options] info | init | stats | clear
  uris.py [-v... options] couch list
  uris.py [-v... options] memdebug
  uris.py -h|--help
  uris.py help [CMD]
  uris.py --version

Options:
  -s SESSION, --session-name SESSION
                Should be bookmarks [default: default]
  -d REF, --dbref=REF
                SQLAlchemy DB URL [default: %s]
  --no-db       Don't initialize SQL DB connection
  --couch=REF
                Couch DB URL [default: %s]
  --output-format FMT, -O FMT
                json, repr, rst [default: rst]
  --interactive
                Prompt to resolve or override certain warnings.
                XXX: Normally interactive should be enabled if while process
                has a terminal on stdin and stdout.
  --batch
                Overrules `interactive`, exit on errors or strict warnings
  --no-commit   .
  --commit      [default: true]
  --dry-run     Implies `no-commit`
  -v            Increase verbosity
  --verbose     Default
  -q, --quiet   Turn off verbosity
  --strict      ..
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'
  --version     Show version (%s)

See 'help' for manual or per-command usage.
This is the short usage description '-h/--help'.
""" % ( __db__, __couch__, __version__, )
import os
import sys

from script_mpe.libhtd import *



ctx = Taxus(version='bookmarks')

cmd_default_settings = dict(
        create_on_init=False,
        debug=False,
        verbose=1,
        all_tables=True,
        database_tables=False,
        struct_output=False,
    )


### Commands


def cmd_list(NAME, g):
    """List locators in SQL store"""
    global ctx

    if NAME: rs = ctx.Locator.search(ref=NAME)
    else: rs = ctx.Locator.all()
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict: return 1

    ctx.lines_out(rs)


def cmd_couch_list(g):
    global ctx

    for ls in ctx.docs:
        print(ls, ctx.docs[ls])
"""
    for row in ctx.docs.view('bookmarks/list'):
        print(row.id, row.value)
"""



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug,
        info = db_sa.cmd_info,
        init = db_sa.cmd_init,
        clear = db_sa.cmd_reset
))


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    ctx.settings.update(opts.flags)
    opts.flags.update(dict(
        commit = not opts.flags.no_commit and not opts.flags.dry_run,
        verbose = opts.flags.quiet and opts.flags.verbose or 1,
    ))
    if not opts.flags.interactive:
        if os.isatty(sys.stdout.fileno()) and os.isatty(sys.stdout.fileno()):
            opts.flags.interactive = True
    opts.flags.update(dict(
        dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    ))
    return init

def main(opts):

    """
    Execute using docopt-mpe options.
    """
    global ctx, commands

    opts.default = 'list'
    ctx.settings = settings = opts.flags
    settings.apply_contexts = {}
    ctx.init()

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'uris.mpe/%s' % __version__


if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf-8')
    usage = __description__ +'\n\n'+ __short_description__ +'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'BM_DB', __db__ ),
        ( 'COUCH_DB', __couch__ ) )

    db_sa.schema = sys.modules['__main__']
    db_sa.metadata = SqlBase.metadata

    opts = libcmd_docopt.get_opts(usage,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
