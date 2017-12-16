#!/usr/bin/env python
""":created: 2016-09-04

"""
from __future__ import print_function

__description__ = "hier - tag hierarchies"
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.hier.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """
Usage:
  hier.py [options] init
  hier.py [options] info
  hier.py [options] list
  hier.py [options] find LIKE
  hier.py [options] tree TODO
  hier.py [options] record [TAGS...]
  hier.py [options] clear

Options:
  -d REF --dbref=REF
                SQLAlchemy DB URL [default: %s]
  --no-db       Don't initialize SQL DB connection.
  --couch=REF
                Couch DB URL [default: %s]
  -i FILE --input=FILE
  -o FILE --output=FILE
  --add-prefix=PREFIX
                Use this context with the provided tags.
  -I --interactive
  --strict
  --force
  --override-prefix
                ..
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).

""" % ( __db__, __couch__, __version__ )

import os
from pprint import pformat

from sqlalchemy import Column, ForeignKey, Integer, String, Boolean, Text, \
        Table, create_engine, or_
from sqlalchemy.orm import relationship, backref
from sqlalchemy.ext.declarative import declarative_base

import log
import libcmd_docopt
from res.ws import Homedir
from taxus import Taxus
from taxus.util import ORMMixin, ScriptMixin, get_session



### Object classes

from taxus import SqlBase
metadata = SqlBase.metadata

from taxus import v0
from taxus.v0 import Node, GroupNode, Folder, ID, Space, Name, Tag, Topic
models = [ Node, GroupNode, Folder, ID, Space, Name, Tag, Topic ]

ctx = Taxus(version='hier')

cmd_default_settings = dict(verbose=1, partial_match=True,
        session_name='default', print_memory=False)


### Commands

def cmd_info(settings):

    """
        Verify DB connection is working. Print some settings and storage stats.
    """
    global ctx

    for l, v in (
            ( 'Settings Raw', pformat(settings.todict()) ),
            ( 'DBRef', settings.dbref ),
            ( "Number of tables", len(metadata.tables.keys()) ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

    empty = []
    for t in metadata.tables:
        try:
            cnt = ctx.sa_session.query(metadata.tables[t].count()).all()[0][0]
            if cnt:
                log.std("  {blue}%s{default}: {bwhite}%s{default}", t, cnt)
            else:
                empty.append(t)
        except Exception as e:
            log.err("Count failed for %s: %s", t, e)

    if empty:
        log.warn("Found %i empty tables: %s", len(empty), ', '.join(empty))

    log.std('{green}info {bwhite}OK{default}')
    settings.print_memory = True


def cmd_list(settings):
    """
        List to root tags.
    """
    global ctx
    roots = ctx.sa_session.query(Tag).filter(Tag.contexts == None).all()
    for root in roots:
        print(root.name)


def cmd_find(settings, LIKE):
    """
        Look for tag.
    """
    global ctx
    alikes = ctx.sa_session.query(Tag).filter(Tag.name.like(LIKE)).all()
    for tag in alikes:
        print(tag.name)


def cmd_init(settings):
    """
        Commit SQL DDL to storage schema. Creates DB file if not present.
    """
    sa = get_session(settings.dbref, initialize=True, metadata=metadata)


def cmd_clear(settings):
    """
        Drop all tables and re-create.
    """
    sa = get_session(settings.dbref, metadata=metadata)
    for name, table in metadata.tables.items():

        print(table.delete())
        sa.execute(table.delete())

    sa.commit()

    sa = get_session(settings.dbref, initialize=True, metadata=metadata)


def cmd_record(TAGS, g):
    """
        Record tags/paths. Report on inconsistencies.
    """
    global ctx
    assert TAGS # TODO: read from stdin
    for raw_tag in TAGS:
        Tag.record(raw_tag, ctx.sa_session, g)


"""
  hier.py [options] couchdb prefix NAME BASE
"""
def cmd_couchdb_prefix(settings, opts, NAME, BASE):
    """
    1. If prefix does not exists, add it to the recorded prefixes.
    2. Find all URLs starting with Base URL, and strip base, add Prefix.
    3. For existing Prefixes, update their href for those with URLs below
       Base URL.
    """


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help
commands['memdebug'] = libcmd_docopt.cmd_memdebug


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    ctx.settings.update(opts.flags)
    opts.flags.update(ctx.settings)
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    return init

def main(opts):

    """
    Execute command.
    """
    global ctx, commands

    ws = Homedir.require()
    ws.yamldoc('bmsync', defaults=dict(
            last_sync=None
        ))
    ctx.ws = ws
    ctx.settings = settings = opts.flags
    # FIXME: want multiple SqlBase's
    #metadata = SqlBase.metadata = ctx.reset_metadata()
    ctx.init()#SqlBase.metadata)

    ret = libcmd_docopt.run_commands(commands, settings, opts)
    if settings.print_memory:
        libcmd_docopt.cmd_memdebug(settings)
    return ret

def get_version():
    return 'hier.mpe/%s' % __version__


if __name__ == '__main__':
    import sys

    usage = libcmd_docopt.static_vars_from_env(__usage__,
        ( 'HIER_DB', __db__ ),
        ( 'COUCH_DB', __couch__ ) )

    opts = libcmd_docopt.get_opts(__description__ + '\n' + usage,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
