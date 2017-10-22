#!/usr/bin/env python
"""db_sa - DB init/reinit/stats for SQLite, using SQLAlchemy schema
"""
from __future__ import print_function
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.db.sqlite'
__usage__ = """
db_sa - SQLAlchemy DB init

Intialize SQlite from schema, and inspect or maintain.

Usage:
  db.py [options] (info|show|init|reset|stats|describe) [<schema>]
  db.py list MODEL [<schema>] [ID]
  db.py export <schema> JSON
  db.py help
  db.py -h|--help
  db.py --version

Options:
    -q, --quiet   Quiet operations
    -y --yes
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s].
    --output FILE
                  Write output to file.
    --diagram SADISPLAY
                  If 'describe' [env: DB_SA_DIA]
    --all-tables  For stats, show record count for all tables in metadata,
                  not just current models.
    --database-tables
                  Implies --all-tables, but reload metadata from database
                  Iow. this shows the actual schema in case of mismatch.
    -v
    --verbosity VALUE
                  Increase verbosity.
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__ )
from datetime import datetime
import os
import re
import hashlib
import inspect
import codecs

import zope.interface
import zope.component
from sqlalchemy import MetaData, Table
from sqlalchemy.schema import CreateTable
import sadisplay

import log
import libcmd_docopt
import reporter
import taxus
from taxus.init import SqlBase
from taxus.util import get_session



models = [ taxus.Space, ]


@reporter.stdout.register(Table, [], key='Table')
def format_Table(table):
    log.std("{blue}%s{default}: {bwhite}%s{default}", table.name,
            str(CreateTable(table)).strip()
            #.compile(engine)
        )


# globals set in main
schema = None
metadata = None


def reload_metadata(settings):
    global metadata
    # Reset metadata from database, overrides SqlBase loaded..
    metadata = MetaData()
    schema.get_session(settings.dbref, metadata=metadata)
    metadata.reflect()

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
    print("Tables in schema:", ", ".join(metadata.tables.keys()))
    if not settings.yes:
        x = raw_input("This will destroy all data? [yN] ")
        if not x or x not in 'Yy':
            return 1
    metadata.drop_all()
    metadata.create_all()

def cmd_stats(settings, opts):
    """
    Print table record stats.
    """
    global metadata
    sa = schema.get_session(settings.dbref, metadata=metadata)
    if opts.flags.all_tables or opts.flags.database_tables:
        if opts.flags.database_tables:
            reload_metadata(settings)
            log.info("{yellow}Loaded tables from DB{default}")
        for t in metadata.tables:
            try:
                log.std("{blue}%s{default}: {bwhite}%s{default}",
                        t, sa.query(metadata.tables[t].count().alias("cnt")).all()[0][0])
            except Exception as e:
                log.err("Count failed for %s: %s", t, e)
        log.std("%i tables, done.", len(metadata.tables))
    else:
        if hasattr(schema, 'models'):
            models = schema.models
        else:
            models = [
                    getattr(schema, x) for x in dir(schema)
                    if inspect.isclass(getattr(schema, x))
                        and issubclass( getattr(schema, x), schema.SqlBase ) ]
        for m in models:
            try:
                log.std("{blue}%s{default}: {bwhite}%s{default}",
                        m.__name__, sa.query(m).count())
            except Exception as e:
                log.err("Count failed for %s: %s", m, e)
        log.std("%i models, done.", len(models))

def cmd_info(settings):
    if opts.flags.database_tables:
        reload_metadata(settings)
        log.std("{yellow}Loaded tables from DB{default}")
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

def cmd_list(MODEL, ID, settings):
    sa = schema.get_session(settings.dbref, metadata=metadata)
    Model = getattr(schema, MODEL)
    Model.sessions['default'] = sa
    if ID:
        m = sa.query(Model).filter(Model.id==ID).all()
        print(m)
    else:
        for it in Model.all():
            print(it)

def cmd_show(settings):
    for name, table in metadata.tables.items():
        log.std('{green}%s{default}: {bwhite}%s{default}',
                name, "{default}, {bwhite}".join(table.columns.keys()))

def cmd_describe(settings, opts):
    """
        Describe DB by printing SQL schema, or diagram.
    """
    if opts.flags.database_tables:
        reload_metadata(settings)
    if hasattr(schema, 'models'):
        models = schema.models
    #[getattr(model, attr) for attr in dir(model)],
    models = [
            getattr(schema, x) for x in dir(schema)
            if inspect.isclass(getattr(schema, x))
                and issubclass( getattr(schema, x), schema.SqlBase ) ]
    #metadata.reflect(engine)
    if opts.flags.diagram:
        dia = opts.flags.diagram
        name = opts.args.schema
        desc = sadisplay.describe(
            models,
            show_methods=True,
            show_properties=True,
            show_indexes=True,
        )
        with codecs.open(name+'.'+dia, 'w', encoding='utf-8') as f:
            f.write(getattr(sadisplay, dia)(desc))

    elif not opts.flags.quiet or opts.flags.output:
        # Print
        out = reporter.Reporter(out=opts.output)
        for table in metadata.tables.values():
            reporter.stdout.Table(table)

    else:
        return 1


def cmd_export(settings, opts):
    global metadata
    sa = schema.get_session(settings.dbref, metadata=metadata)
    for m in schema.models:
        print(m)
        # sa.query



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'db_sa.mpe/%s' % __version__

if __name__ == '__main__':
    import sys

    opts = libcmd_docopt.get_opts(__usage__, version=get_version())

    # Override dbref setting from schema
    if opts.flags.v or opts.flags.verbosity:
        log.category = 6
        # FIXME: log.category log.test()

    # schema corresponds to module name
    if opts.args.schema:
        log.note("Using schema %r", opts.args.schema)
        schema = __import__(os.path.splitext(opts.args.schema)[0])
    else:
        log.note("Using local schema %s", __name__)
        schema = sys.modules[__name__]

    metadata = schema.SqlBase.metadata

    if opts.flags.dbref == __db__:
        if hasattr(schema, '__db__'):
            opts.flags.dbref = schema.__db__

    if ':/' not in opts.flags.dbref: # FIXME: scan for uri properly (regex)
        opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
        log.note("Set DB-ref to %r" % opts.flags.dbref)

    if opts.flags.output:
        opts.output = open(opts.flags.output, 'a+')
    else:
        opts.output=sys.stdout

    sys.exit(main(opts))
