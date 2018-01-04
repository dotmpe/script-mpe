#!/usr/bin/env python
"""
:Created: 2014-09-07
:Updated: 2017-04-16

TODO figure out model. look at folder.py too
TODO: create all nodes; name, description, hierarchy and dump/load json/xml
    most dirs in tree ~/htdocs/
    headings in ~/htdocs/personal/journal/*.rst
    files in ~/htdocs/note/*.rst

Commands:
  - list
  - name | tag | topic | host | domain
  - read-list
  - new
  - get
  - get-name
  - get-id

  Database:
    - info | init | stats | clear

TODO:
  topic.py [options] search STR
  topic.py [options] find STR
  topic.py [options] bulk-get [PATHS...|-]
"""
from __future__ import print_function
__description__ = "topic - ..."
__short_description__ = "topci - ..."
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.topic.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """

Usage:
  topic.py [options] [list]
  topic.py [options] (name|tag|topic|host|domain) [NAME]
  topic.py [options] read-list LIST
  topic.py [options] new NAME [REF]
  topic.py [options] get REF
  topic.py [options] get-name NAME
  topic.py [options] get-id ID
  topic.py [options] x-dump
  topic.py [options] bulk-add [PATHS...|-]
  topic.py [options] info | init | stats | clear
  topic.py -h|--help
  topic.py help [CMD]
  topic.py --version

Options:
  --output-format FMT
                json, repr
  --provider KEY=SPEC...
                Initialize projects or contexts API.
  --apply-tag TAGSPEC...
                Apply given tags to each item in file.
  --paths
                TODO: replace with --format=paths
  -d REF --dbref=REF
                SQLAlchemy DB URL [default: %s]
  --no-db       Don't initialize SQL DB connection.
  --couch=REF
                Couch DB URL [default: %s]
  --interactive
                Prompt to resolve or override certain warnings.
                XXX: Normally interactive should be enabled if while process has a
                terminal on stdin and stdout.
  --batch
                Overrules `interactive`, exit on errors or strict warnings.
  --auto-commit .
  --no-commit   .
  --commit      [default: true].
  --dry-run     Echo but don't make actual changes. This does all the
  -h --help     Show this usage description.
  --version     Show version (%s).

See 'help' for manual or per-command usage.
This is the short usage description '-h/--help'.
""" % ( __db__, __couch__, __version__ )

import os
import re
import sys
from datetime import datetime

from script_mpe.libhtd import *
from script_mpe.taxus.v0 import \
    Name, Tag, Topic, Folder


models = [ Name, Tag, Topic, Folder ]

ctx = Taxus(version='topic')

cmd_default_settings = dict( verbose=1,
        debug=False,
        all_tables=True,
        database_tables=False
    )


@reporter.stdout.register(Topic, [])
def format_Topic_item(topic):
    log.std(
"{blue}%s{bblack}. {bwhite}%s {bblack}[ about:{magenta}%s {bblack}] %s %s %s{default}" % (
                topic.topic_id,
                topic.path(),
                topic.supernode_id,

                str(topic.date_added).replace(' ', 'T'),
                str(topic.date_updated).replace(' ', 'T'),
                str(topic.date_deleted).replace(' ', 'T')
            )
        )


### Commands


def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(SqlBase.metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)


def cmd_stats(g):
    global ctx
    db_sa.cmd_sql_stats(g, sa=ctx.sa_session)
    if g.debug:
        log.std('{green}info {bwhite}OK{default}')
        g.print_memory = True


def cmd_list(g):
    global ctx
    sa = Topic.get_session('default', g.dbref)
    out = reporter.Reporter()
    assert out.get_context_path() == ('rst', 'paragraph')
    #out.start_list()
    #assert out.get_context_path() == ('rst', 'list')
    for t in Topic.all():
        if g.paths:
            out.out.write(t.path()+'\n')
        else:
            reporter.stdout.Topic(t)
            #out.print_item(t)
    out.finish()


def cmd_new(NAME, REF, settings):
    sa = Topic.get_session('default', settings.dbref)
    about = Topic.byName(REF)
    #store = Topic.start_master_session()
    #print store
    #topic = store.Topic.byName(REF)
    #if topic:
    #    pass
    #else:
    #    topic = store.Topic.forge(name=NAME)
    #    store.commit()
    #reporter.stdout.Topic(topic)
    # XXX: old
    topic = Topic.byName(NAME)
    if topic:
        log.std("Found existing topic %s, created %s", topic.name,
                topic.date_added)
    else:
        if about:
            topic = Topic(name=NAME, super_id=about.topic_id)
        else:
            topic = Topic(name=NAME)
        topic.init_defaults()
        sa.add(topic)
        if settings.commit:
            sa.commit()
        log.std("Added new topic %s", topic.name)
    reporter.stdout.Topic(topic)


def cmd_get(REF, settings):
    Topic.get_session('default', settings.dbref)
    if REF.isdigit() and not cmd_getId(REF, settings):
        return
    return cmd_getName(REF, settings)


def cmd_getId(ID, settings):
    Topic.get_session('default', settings.dbref)
    topic = Topic.byKey(dict(topic_id=ID))
    if topic:
        reporter.stdout.Topic(topic)
    else:
        return 1


def cmd_getName(NAME, settings):
    Topic.get_session('default', settings.dbref)
    topic = Topic.byName(NAME)
    if topic:
        reporter.stdout.Topic(topic)
    else:
        return 1


def cmd_x_dump(settings):
    Topic.get_session('default', settings.dbref)
    for t in Topic.all():
        reporter.stdout.Topic(t)
	reporter.out.write(t.dump())


def cmd_bulk_add(settings):
    sa = Topic.get_session('default', settings.dbref)
    for p in sys.stdin.readlines():
        p = p.strip()
        es = p.split('/')
        s = None
        while es:
            e = es.pop(0)
            i = Topic.byName(e)
            if not i:
                i = Topic(e, super=s)
                sa.add(i)
            s = i
            print(i)
        print(p)
    sa.commit()


def cmd_read_list(LIST, settings):
    """Read items, resolving issues interactively and making sure items are
    committed to any backends. """
    res.list.parse(LIST, settings)


def cmd_write_list(LIST, PROVIDERS, settings):
    """Retrieve all items from given backens and write to list file. """
    for provider in PROVIDERS:
        res.list.write(LIST, provider, settings)



"""
TODO: create item list from index, and vice versa uid:FEGl time:17:43Z

1. Parse list, like todo.txt
2. Keep db_sa SQLite
    1. Init db from list
    2. Update existing db from list
"""


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug,
        info = db_sa.cmd_info,
        init = db_sa.cmd_init,
        clear = db_sa.cmd_reset,
))


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    ctx.settings.update(opts.flags)
    opts.flags.update(ctx.settings)
    opts.flags.update(dict(
        default = 'info',
        commit = not opts.flags.no_commit and not opts.flags.dry_run and not opts.flags.no_db,
        verbose = opts.flags.quiet and opts.flags.verbose or 1,
    ))
    if not opts.flags.interactive:
        if os.isatty(sys.stdout.fileno()) and os.isatty(sys.stdout.fileno()):
            opts.flags.interactive = True
    opts.flags.update(dict(
        auto_commit = not opts.flags.no_commit and not opts.flags.no_db,
        dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    ))
    if opts.flags.auto_commit:
        opts.flags.auto_commit = int(opts.flags.auto_commit)
    return init

def main(opts):

    """
    Execute command.
    """
    global ctx, commands

    ctx.settings = settings = opts.flags
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'topic.mpe/%s' % __version__


if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf-8')
    usage = __description__ +'\n\n'+ __short_description__ +'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'TOPIC_DB', __db__ ),
        ( 'COUCH_DB', __couch__ ) )

    db_sa.schema = sys.modules['__main__']
    db_sa.metadata = SqlBase.metadata

    opts = libcmd_docopt.get_opts(usage,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
