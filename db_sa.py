#!/usr/bin/env python
"""db_sa - SQLAlchemy DB init

Use to intialize SQlite schema.

Usage:
  db.py [options] (show|init|reset|stats) <schema>
  db.py info
  db.py help
  db.py -h|--help
  db.py --version

Options:
    -y --yes
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: ~/.bookmarks.sqlite].
Other flags:
    -h --help     Show this screen.
    --version     Show version.

"""
from datetime import datetime
import os
import re
import hashlib

from docopt import docopt
import zope.interface
import zope.component

import log
import util



__version__ = '0.0.0'

# set in main
metadata = None
schema = None


def cmd_init(settings):
    """
    Initialize if the database file doest not exists,
    and update schema.
    """
    schema.get_session(settings.dbref, metadata=metadata)
    # XXX: update schema..
    metadata.create_all()

def cmd_reset(settings):
    """
    Drop all tables and recreate schema.
    """
    schema.get_session(settings.dbref, metadata=metadata)
    if not settings.yes:
        x = raw_input("This will destroy all data? [yN] ")
        if not x or x not in 'Yy':
            return 1
    metadata.drop_all()
    metadata.create_all()

def cmd_stats(settings):
    """
    Print table record stats.
    """
    sa = schema.get_session(settings.dbref, metadata=metadata)
    for m in schema.models:
        log.std("{blue}%s{default}: {bwhite}%s{default}", 
                m.__name__, sa.query(m).count())

def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

def cmd_show(settings):
    for name, table in metadata.tables.items():
        log.std('{green}%s{default}: {bwhite}%s{default}', 
                name, "{default}, {bwhite}".join(table.columns.keys()))


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags

    # FIXME: share default dbref uri and path, also with other modules
    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'db_sa.mpe/%s' % __version__

if __name__ == '__main__':
    #bookmarks.main()
    import sys
    from pprint import pformat
    opts = util.get_opts(__doc__, version=get_version())
    if opts.args.schema:
        schema = __import__(opts.args.schema)
        metadata = schema.SqlBase.metadata
    sys.exit(main(opts))



