#!/usr/bin/env python
""":created: 2014-10-5

script_mpe + taxus

TODO: manage schemas and datastores.

Work with models across databases, synchronize base types through master
database.
"""
__description__ = "cllct - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.cllct.sqlite'
__usage__ = """
Usage:
  cllct.py [options] [info|list|init]
  cllct.py [options] [status|sync] SCHEMA
  cllct.py [options] get REF
  cllct.py [options] new NAME
  cllct.py -h|--help
  cllct.py --version

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
from glob import glob

import log
import util
import reporter
from taxus.init import SqlBase, get_session
from taxus.util import ORMMixin, current_hostname
from taxus import \
    Node, Name, Tag, Topic, \
    ID, \
    Space


metadata = SqlBase.metadata
models = [ Node, ID, Space ]


@reporter.stdout.register(Space, [])
def format_Space_item(space):
    log.std(
"{blue}%s{bblack}. {bwhite}%s {bblack}[ about:{magenta}%s {bblack}] %s %s %s{default}" % (
                space.space_id,
                space.global_id,
                space.classes,

                str(space.date_added).replace(' ', 'T'),
                str(space.date_updated).replace(' ', 'T'),
                str(space.date_deleted).replace(' ', 'T')
            )
        )


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
    except Exception, e:
        log.std('{magenta} * {bwhite}DB Connection {default}[{red}Error{default}]: %s', e)

def cmd_init(settings):

    """
    """

    sa = ORMMixin.get_session('default', settings.dbref)
    metadata.create_all()

    # enter cllct, should be using it as default session

    store = Space.start_master_session()
    store.init()

    # modeltype, dbref
    canonical = {}

    for session in store.sessions:
        schema = __import__(name)
        dbref = Klass.assert_dbref(schema.__db__)
        class_str = ", ".join(map(lambda x:x.className(), schema.models))
        space = Space(global_id=dbref, classes=class_str)
        space.init_defaults()
        for x in schema.models:
            assert x.className() not in models, x
            assert x not in canonical, (sessions, x)
            canonical[x] = dbref

        sa.add(space)
    sa.commit()


def cmd_list(settings):

    """
    TODO: list all nodes from all databases,
        or just all databases.
    """

    sa = Space.get_session('default', settings.dbref)
    for t in Space.all():
        reporter.stdout.Space(t)


def cmd_get(REF, settings):
    sa = Node.get_session('default', settings.dbref)
    #print Node.byKey(dict(cllct_id=REF))
    #print Node.byName(REF)
    Root, nid = Node.init_ref(REF)
    print Root.fetch_instance(nid, sa=sa)

def cmd_new(NAME, settings):
    sa = Node.get_session('default', settings.dbref)
    cllct = Node(name=NAME)
    sa.add(cllct)
    sa.commit()
    reporter.stdout.Node(cllct)

def cmd_status(SCHEMA, settings):

    """
    Get new nodes from databases,
    and update subdatabase increment.
    Possibly this should be in db_sa and work for any master database.
    Work on Node-subtrees first.
    """

    store = Node.start_master_session()

    if SCHEMA.endswith('.py'):
        SCHEMA = SCHEMA[:-3]
    schema = __import__(SCHEMA)

    store.init()

    for session in Node.sessions:
        print session
        for model in schema.models:
            try:
                print model, model.date_id(None, session)
            except Exception, e:
                print e


def cmd_sync(SCHEMA, settings):
    """
    """



### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags

    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    opts.default = 'info'

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'cllct.mpe/%s' % __version__

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





