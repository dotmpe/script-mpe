#!/usr/bin/env python
""":created: 2016-09-04

"""
from __future__ import print_function
__description__ = "hier - tag hierarchies"
__version__ = '0.0.0'
__db__ = '~/.hier.sqlite'
__usage__ = """
Usage:
  hier.py [options] init
  hier.py [options] info
  hier.py [options] list
  hier.py [options] tree TODO
  hier.py [options] record [TAGS...]
  hier.py [options] clear

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    -i FILE --input=FILE
    -o FILE --output=FILE

Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

Commands:
    init
        Commit SQL DDL to storage schema. Creates DB file if not present.
    info
        Verify DB connection is working. Print some settings and storage stats.
    list
        List to root tags.

""" % ( __db__, __version__ )
import os
import resource
from pprint import pformat

from sqlalchemy import Column, ForeignKey, Integer, String, Boolean, Text, \
        Table, create_engine
from sqlalchemy.orm import relationship, backref
from sqlalchemy.ext.declarative import declarative_base

import lib
import log
import util
from taxus.util import ORMMixin, ScriptMixin, get_session


SqlBase = declarative_base()
metadata = SqlBase.metadata


### Object classes

tag_context_table = Table('tag_context', metadata,
        Column('tag_id', Integer, ForeignKey('tags.id'), primary_key=True),
        Column('ctx_id', Integer, ForeignKey('tags.id'), primary_key=True)
)
class Tag(ORMMixin, SqlBase):

    """
    """

    __tablename__ = 'tags'

    tag_id = Column('id', Integer, primary_key=True)
    name = Column(String(255), unique=True, nullable=False)
    label = Column(String(255), unique=True, nullable=True)
    description = Column(Text, nullable=True)

Tag.contexts = relationship('Tag', secondary=tag_context_table,
            primaryjoin=( Tag.tag_id == tag_context_table.columns.tag_id ),
            secondaryjoin=( Tag.tag_id == tag_context_table.columns.ctx_id ),
            backref='contains')


### Commands

def cmd_info(settings):

    """
    Print some settings, stats.
    """

    for l, v in (
            ( 'Settings Raw', pformat(settings.todict()) ),
            ( 'DBRef', settings.dbref ),

            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
            ( "Table lengths", "" ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

    sa = get_session(settings.dbref, metadata=metadata)

    for t in metadata.tables:
        try:
            log.std("  {blue}%s{default}: {bwhite}%s{default}",
                    t, sa.query(metadata.tables[t].count()).all()[0][0])
        except Exception, e:
            log.err("Count failed for %s: %s", t, e)

    # peak memory usage (bytes on OS X, kilobytes on Linux)
    res_usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    if os.uname()[0] == 'Linux':
        res_usage /= 1024; # kilobytes?
    # XXX: http://stackoverflow.com/questions/938733/total-memory-used-by-python-process
    #res_usage /= resource.getpagesize()

    # FIXME: does not use dbref according to settings, may fail/report wrong file
    db_size = os.path.getsize(os.path.expanduser(__db__))

    for l, v in (
            ( 'Storage Size', lib.human_readable_bytesize( db_size ) ),
            ( 'Resource Usage', lib.human_readable_bytesize(res_usage) ),
        ):
            log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

    #log.std('\n{green}stat {bwhite}OK{default}')


def cmd_list(settings):
    sa = get_session(settings.dbref, metadata=metadata)
    roots = sa.query(Tag).filter(Tag.contexts == None).all()
    for root in roots:
        print(root)

def cmd_init(settings):
    sa = get_session(settings.dbref, initialize=True, metadata=metadata)

def cmd_clear(settings):
    sa = get_session(settings.dbref, metadata=metadata)

    for name, table in metadata.tables.items():

	print(table.delete())
	sa.execute(table.delete())

    sa.commit()

    sa = get_session(settings.dbref, initialize=True, metadata=metadata)


def cmd_record(settings, TAGS):
    "Record tags/paths. Report on inconsistencies. "
    sa = get_session(settings.dbref, initialize=True, metadata=metadata)
    assert TAGS, "TODO: read from stdin"
    for raw_tag in TAGS:
        if '/' in raw_tag:
            pass
        else:
            tag = Tag(name=raw_tag)
            sa.add(tag)
            sa.commit()
            print(raw_tag)



### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    values = opts.args

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'hier.mpe/%s' % __version__

if __name__ == '__main__':
    import sys

    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))

