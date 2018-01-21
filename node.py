#!/usr/bin/env python
""":created: 2014-09-08
:updated: 2014-10-12

TODO: experiment with nodes from other DBs. Sync to and from master.
"""
from __future__ import print_function

__description__ = "node - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.node.sqlite'
__usage__ = """
Usage:
  node.py [options] [info|list]
  node.py [options] get REF
  node.py [options] new NAME
  node.py [options] info | init | stats | clear
  node.py -h|--help
  node.py help [CMD]
  node.py --version

Options:
    --schema SCHEMA
                  Look at module for DB.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]

Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).
""" % ( __db__, __version__ )

from datetime import datetime
import os
import re

from script_mpe.libhtd import *
from script_mpe.taxus import core


metadata = SqlBase.metadata


# used by db_sa
models = [ core.Node, ]#Name, Tag, Topic ]

@reporter.stdout.register(core.Node, [])
def format_Node_item(node):
    log.std(
"{blue}%s{bblack}. {bwhite}%s {bblack}[ {bblack}] {default}" % (
                node.node_id,
                node.name,
            )
        )



### Commands

def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)
    # try to connect
    try:
        sa = Node.get_session('default', settings.dbref)
        log.std('{magenta} * {bwhite}DB Connection {default}[{green}OK{default}]')
    except Exception as e:
        log.std('{magenta} * {bwhite}DB Connection {default}[{red}Error{default}]: %s', e)

def cmd_list(settings):
    sa = Node.get_session('default', settings.dbref)
    for t in Node.all():
        print(t, t.date_added, t.date_updated)

def cmd_get(REF, settings):

    """
    Retrieve and format node.
    TODO: full type-specific representation may depend on sub-database.
    """

    sa = Node.get_session('default', settings.dbref)
    Root, nid = Node.init_ref(REF)
    node = Root.fetch_instance(nid, sa=sa)
    reporter.stdout.Node(node)

def cmd_new(NAME, settings):

    """
    """

    sa = Node.get_session('default', settings.dbref)
    node = Node(name=NAME)
    node.init_defaults()
    sa.add(node)
    sa.commit()
    reporter.stdout.Node(node)

### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'info'

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'node.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__description__ + '\n' + __usage__, version=get_version())
    if opts.flags.schema:
        schema = __import__(os.path.splitext(opts.flags.schema)[0])
        metadata = schema.SqlBase.metadata
        if hasattr(schema, '__db__'):
            opts.flags.dbref = taxus.ScriptMixin.assert_dbref(schema.__db__)
        else:
            log.warn("{yellow}Warning: {default}no DB found and none provided.");
    else:
        opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
