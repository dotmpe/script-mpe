#!/usr/bin/env python
""":created: 2014-09-08

TODO: create all nodes; name, description, hierarchy and dump/load json/xml
    most dirs in tree ~/htdocs/
    headings in ~/htdocs/personal/journal/*.rst
    files in ~/htdocs/note/*.rst
"""
__description__ = "node - "
__version__ = '0.0.0'
__db__ = '~/.node.sqlite'
__usage__ = """
Usage:
  node.py [options] [info|list]
  node.py [options] get REF
  node.py -h|--help
  node.py --version

Options:
    --schema SCHEMA
                  Look at module for DB.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]

Other flags:
    -h --help     Show this screen.
    --version     Show version (%s).
""" % ( __db__, __version__ )

from datetime import datetime
import os
import re

import log
import util
from taxus.init import SqlBase, get_session
from taxus import \
    Node, Name, Tag, Node


metadata = SqlBase.metadata


def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

def cmd_list(settings):
    sa = Node.get_session('default', settings.dbref)
    for t in Node.all():
        print t, t.date_added, t.last_updated

def cmd_get(REF, settings):
    sa = Node.get_session('default', settings.dbref)
    print Node.byKey(dict(node_id=REF))
    print Node.byName(REF)


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

    opts.default = 'info'

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'node.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    if opts.flags.schema:
        schema = __import__(os.path.splitext(opts.flags.schema)[0])
        metadata = schema.SqlBase.metadata
        if hasattr(schema, '__db__'):
            opts.flags.dbref = schema.__db__
        else:
            log.warn("{yellow}Warning: {default}no DB found and none provided.");
    sys.exit(main(opts))


