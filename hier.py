#!/usr/bin/env python
""":created: 2016-09-04
:updated: 2017-12-26

- Record generic tags, as unicode strings with associated ASCII ID.
- Track generic added, updated and deleted datetime and state for tags.
- XXX: Annotate with number to wordnet noun or verb synset for precise semantic,
  and automatic categorization.
- Or turn tags into custom group for other tags, and imply transitive relations.
- XXX: NLTK tokenize, base, infer singular<->plural. Record antonym relations.

Commands:
  - roots - List root tags
  - find - List tags by name or group(s), or everything.
  - tree - Like 'find' with structured output instead of plain list-lines.
  - delete - Drop nodes by name, or groups, recursively.
  - assert-tags - Create missing tags, fail on missing in strict mode.
  - assert - Create missing node or fail in strict mode.
  - group - Ungroup and move subs. Set ID's type to group.
  - up | ungroup - Move nodes up until they are root. Or ungroup completely.
  - cp - Create new node name, with attributes from src node.
  - mv - Move nodes in src-spec to below dest group.

  Database:
    - info | init | stats | clear
"""
from __future__ import print_function

__description__ = "hier - tag hierarchies"
__short_description__ = "Maintain records for a unique set of tags, and"+\
    " annotate, disambiguate, link and categorize."
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.hier.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """
Usage:
  hier.py [options] info | init | stats | clear
  hier.py [options] roots [ LIKE ]
  hier.py [options] ( find | tree | delete ) [ LIKE [ GROUP... ] ]
  hier.py [options] assertall TAGS...
  hier.py [options] assert NAME [ TYPE ]
  hier.py [options] group ID SUB...
  hier.py [options] ( up | ungroup ) SUB...
  hier.py [options] cp SRC DEST
  hier.py [options] mv SRC... DEST
  hier.py [options] wordnet WORD
  hier.py [options] clear
  hier.py help [CMD]
  hier.py -h|--help

Options:
  -d REF --dbref=REF
                SQLAlchemy DB URL [default: %s] (sh env 'HIER_DB')
  --no-db       Don't initialize SQL DB connection or query DB.
  --couch=REF
                Couch DB URL [default: %s] (sh env 'COUCH_DB')
  -i FILE --input=FILE
  -o FILE --output=FILE
  --add-prefix=PREFIX
                Use this context with the provided tags.
  --interactive
                Prompt to resolve or override certain warnings.
                XXX: Normally interactive should be enabled if while process has a
                terminal on stdin and stdout.
  --recurse
                Make action recursive.
  --strict
                Abort on first warning.
  --force
                Assume yes or override warning. Overrules `interactive` and
                `strict`.
  --batch
                Overrules `interactive`, exit on errors or strict warnings.
  --override-prefix
                ..
  --print-memory
                Print memory usage just before program ends.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).

See 'help' for manual or per-command usage.
This is the short usage description '-h/--help'.

""" % ( __db__, __couch__, __version__ )

import os

from sqlalchemy import Column, ForeignKey, Integer, String, Boolean, Text, \
        Table, create_engine, or_
from sqlalchemy.orm import relationship, backref
from sqlalchemy.ext.declarative import declarative_base

import log
import libcmd_docopt
import db_sa
from lib import Prompt
from libwn import *
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

cmd_default_settings = dict(verbose=1,
        partial_match=True,
        session_name='default',
        print_memory=False,
        all_tables=True, # FIXME
        database_tables=False
    )


### Commands


def cmd_roots(LIKE, g):
    """
        List root tags, optionally filtered by like.
    """

    global ctx
    q = ctx.sa_session.query(Tag).filter(Tag.contexts == None)
    if LIKE: q = q.Tag.name.like(LIKE)
    for root in q.all():
        print(root.name)


def cmd_find(settings, LIKE, GROUP):
    """
        Look for tag by name, everywhere or in group(s).
        With `recurse` option, require group(s) and look over each sub too.
        Use `max-depth` to control maximum recursion level, and `count` or
        `first` to limit results.
    """

    global ctx
    q = ctx.sa_session.query(Tag)
    if GROUP: q = q.filter(Tag.contexts == GROUP)
    q = q.filter(Tag.name.like(LIKE))
    for tag in q.all():
        print(tag.name)


def cmd_tree(SUB, GROUP, g):
    """
        Like 'find' with structured output instead of plain list-lines.
    """
    global ctx
    # TODO


def cmd_assertall(TAGS, g):
    """
        Record tags/paths. Report on inconsistencies.
    """

    global ctx
    assert TAGS # TODO: read from stdin
    for raw_tag in TAGS:
        Tag.record(raw_tag, ctx.sa_session, g)


def cmd_delete(SUB, GROUP, g):
    """
        Drop nodes by name, or groups, recursively.
    """
    global ctx
    # TODO


def cmd_wordnet(WORD, g):
    """
        Import word and all of its hypernyms from wordnet.
    """
    global ctx

    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    i = 0
    if not syn:
        if not g.interactive:
            log.stderr( "Multiple synonyms, enter an exact word name or "+
                    "enable interactive mode")
            return 1
        items = [ short_def(s) for s in syns ],
        i = Prompt.pick(None, items=items, num=True)

    print_short_def(syns[i])


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


db_sa.metadata = metadata
def cmd_stats(g):
    global ctx
    db_sa.cmd_sql_stats(g, sa=ctx.sa_session)


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

    usage = __description__ +'\n\n'+ __short_description__ +'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'HIER_DB', __db__ ),
        ( 'COUCH_DB', __couch__ ) )

    opts = libcmd_docopt.get_opts(usage,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
