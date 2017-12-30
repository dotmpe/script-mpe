#!/usr/bin/env python
"""
:Created: 2017-08-13

Commands:

  Database:
    - info | init | stats | clear
"""
from __future__ import print_function
__description__ = "uris - "
__short_description__ = "..."
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.bookmarks.sqlite'
__usage__ = """
Usage:
  uris.py [options] list [NAME]
  uris.py [options] info | init | stats | clear
  uris.py -h|--help
  uris.py help [CMD]
  uris.py --version

Options:
  -d REF --dbref=REF
                SQLAlchemy DB URL [default: %s]
  -s SESSION --session-name SESSION
                should be bookmarks [default: default].
  --output-format FMT
                json, repr [default: rst]
  --interactive
                Prompt to resolve or override certain warnings.
                XXX: Normally interactive should be enabled if while process has a
                terminal on stdin and stdout.
  --batch
                Overrules `interactive`, exit on errors or strict warnings.
  --no-commit   .
  --commit      [default: true].
  --dry-run
                Implies `no-commit`.
  -v            Increase verbosity.
  --verbose     Default.
  -q, --quiet   Turn off verbosity.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).

See 'help' for manual or per-command usage.
This is the short usage description '-h/--help'.
""" % ( __db__, __version__, )
import os
import re
import sys
import hashlib
import urllib
from urlparse import urlparse
from datetime import datetime, timedelta

import couchdb
#import zope.interface
#import zope.component
from pydelicious import dlcs_parse_xml
from sqlalchemy import or_
import BeautifulSoup

from script_mpe.libhtd import *
from script_mpe.taxus.v0 import \
        ID, Node, Name, Tag, \
        Locator, Domain, \
        Bookmark



models = [ Locator, Tag, Domain, Bookmark ]

cmd_default_settings = dict(
        debug=False,
        verbose=1,
        all_tables=True,
        database_tables=False,
        exact_match=False,
    )


### Commands


def cmd_list(NAME, settings):
    """List locators"""

    sa = Locator.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Locator.search(name=NAME)
    else:
        rs = Locator.all()
    if not rs:
        log.std("Nothing")

    of = settings.output_format
    if of == 'json':
        def out( d ):
            for k in d:
                if isinstance(d[k], datetime):
                    d[k] = d[k].isoformat()
            return res.js.dumps(d)
    else:
        tpl = taxus.out.get_template("locator.%s" % of)
        out = tpl.render

    for l in rs:
        print(out( l.to_dict() ))


def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(SqlBase.metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)


def cmd_stats(g, sa=None):
    db_sa.cmd_sql_stats(g, sa=sa)
    if g.debug:
        log.std('{green}info {bwhite}OK{default}')
        g.print_memory = True


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
    global cmd_default_settings
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    opts.flags.update(dict(
        commit = not opts.flags.no_commit and not opts.flags.dry_run,
        verbose = opts.flags.quiet and opts.flags.verbose or 1,
    ))
    if not opts.flags.interactive:
        if os.isatty(sys.stdout.fileno()) and os.isatty(sys.stdout.fileno()):
            opts.flags.interactive = True
    opts.flags.update(dict(
        partial_match = not opts.flags.exact_match,
        dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    ))
    return init

def main(opts):

    """
    Execute using docopt-mpe options.
    """

    settings = opts.flags
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'bookmarks.mpe/%s' % __version__

if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf-8')
    usage = __description__ +'\n\n'+ __short_description__ +'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'BM_DB', __db__ ) )

    db_sa.schema = sys.modules['__main__']
    db_sa.metadata = SqlBase.metadata

    opts = libcmd_docopt.get_opts(usage,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
