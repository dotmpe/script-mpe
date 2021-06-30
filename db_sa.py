#!/usr/bin/env python
"""db_sa - DB init/reinit/stats for SQLite, using SQLAlchemy schema

:Created: 2014-08-31
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
  db.py memdebug [<schema>]
  db.py help [ CMD ]
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
    --print-memory
                  Print memory usage just before program ends.
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
from pprint import pformat

import zope.interface
import zope.component
from sqlalchemy import MetaData, Table, func, select
from sqlalchemy.schema import CreateTable
import sadisplay

from script_mpe.libhtd import *
from script_mpe import reporter, mod



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

def cmd_init(g):
    """
    Initialize if the database file doest not exists,
    and update schema.
    """
    schema.get_session(g.dbref, metadata=metadata)
    # XXX: update schema..
    metadata.create_all()

def cmd_reset(g, sa=None):
    """
    Drop all tables and recreate schema.
    """
    global schema, metadata
    if not sa:
        sa = schema.get_session(g.dbref, metadata=metadata)
    print("Tables in schema:", ", ".join(metadata.tables.keys()))
    if not g.yes:
        x = raw_input("This will destroy all data? [yN] ")
        if not x or x not in 'Yy':
            return 1
    metadata.drop_all()
    metadata.create_all()

def cmd_sql_stats(g, sa=None):
    """
    Print table record stats.
    """
    global metadata
    if not sa:
        sa = schema.get_session(g.dbref, 'default', metadata=metadata)
    if g.all_tables or g.database_tables:
        if g.database_tables:
            reload_metadata(g)
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

def cmd_stats(g, sa=None):
    cmd_sql_stats(g, sa=sa)
    if g.debug:
        log.std('{green}info {bwhite}OK{default}')
        g.print_memory = True


def cmd_info(g, sa=None):

    """
        Verify DB connection is working. Print some settings and storage stats.
    """
    global metadata

    if not sa:
        sa = schema.get_session(g.dbref, 'default')

    if hasattr(g, 'database_tables') and g.database_tables:
        reload_metadata(g)
        log.std("{yellow}Loaded tables from DB{default}")

    for l, v in (
            ( 'Settings Raw', pformat(g.todict()) ),
            ( 'DBRef', g.dbref ),
            ( "Number of tables", len(metadata.tables.keys()) ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

    empty = []
    for t in metadata.tables:
        try:
            cnt = sa.execute(select(func.count()).select_from(metadata.tables[t])).scalars().one()
            if cnt:
                log.std("  {blue}%s{default}: {bwhite}%s{default}", t, cnt)
            else:
                empty.append(t)
        except Exception as e:
            log.err("Count failed for %s: %s", t, e)

    if empty:
        log.warn("Found %i empty tables: %s", len(empty), ', '.join(empty))

def cmd_list(MODEL, ID, g):
    sa = schema.get_session(g.dbref, metadata=metadata)
    Model = getattr(schema, MODEL)
    Model.sessions['default'] = sa
    if ID:
        m = sa.query(Model).filter(Model.id==ID).all()
        print(m)
    else:
        for it in Model.all():
            print(it)

def cmd_show(g):
    for name, table in metadata.tables.items():
        log.std('{green}%s{default}: {bwhite}%s{default}',
                name, "{default}, {bwhite}".join(table.columns.keys()))

def cmd_describe(g, opts):
    """
        Describe DB by printing SQL schema, or diagram.
    """
    if g.database_tables:
        reload_metadata(g)
    if hasattr(schema, 'models'):
        models = schema.models
    #[getattr(model, attr) for attr in dir(model)],
    models = [
            getattr(schema, x) for x in dir(schema)
            if inspect.isclass(getattr(schema, x))
                and issubclass( getattr(schema, x), schema.SqlBase ) ]
    #metadata.reflect(engine)
    if g.diagram:
        dia = g.diagram
        name = opts.args.schema
        desc = sadisplay.describe(
            models,
            show_methods=True,
            show_properties=True,
            show_indexes=True,
        )
        with codecs.open(name+'.'+dia, 'w', encoding='utf-8') as f:
            f.write(getattr(sadisplay, dia)(desc))

    elif not g.quiet or g.output:
        # Print
        out = reporter.Reporter(out=opts.output)
        for table in metadata.tables.values():
            reporter.stdout.Table(table)

    else:
        return 1


def cmd_export(g, opts):
    global metadata
    sa = schema.get_session(g.dbref, metadata=metadata)
    for m in schema.models:
        print(m)
        # sa.query



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug
))


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    ret = libcmd_docopt.run_commands(commands, settings, opts)
    if settings.print_memory:
        libcmd_docopt.cmd_memdebug(settings)
    return ret

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
        p = opts.args.schema
        if p.endswith('.py'):
            p = os.path.splitext(p)[0]
        schema = mod.load_module(p)
    else:
        log.note("Using local schema %s", __name__)
        schema = sys.modules[__name__]

    metadata = schema.SqlBase.metadata

    opts.flags.debug = False

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
