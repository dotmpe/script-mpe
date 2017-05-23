#!/usr/bin/env python
""":created: 2014-09-07
:updated: 2017-04-16

TODO figure out model. look at folder.py too
TODO: create all nodes; name, description, hierarchy and dump/load json/xml
    most dirs in tree ~/htdocs/
    headings in ~/htdocs/personal/journal/*.rst
    files in ~/htdocs/note/*.rst

TODO:
  topic.py [options] search STR
  topic.py [options] find STR
  topic.py [options] bulk-get [PATHS...|-]
"""
__description__ = "topic - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.topic.sqlite'
__usage__ = """
Usage:
  topic.py [options] [info|list]
  topic.py [options] (name|tag|topic|host|domain) [NAME]
  topic.py [options] read-list LIST
  topic.py [options] new NAME [REF]
  topic.py [options] get REF
  topic.py [options] get-name NAME
  topic.py [options] get-id ID
  topic.py [options] x-dump
  topic.py [options] x-tree
  topic.py [options] x-mp
  topic.py [options] x-al
  topic.py [options] bulk-add [PATHS...|-]
  topic.py -h|--help
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
    --no-commit   .
    --commit      [default: true].
    -h --help     Show this usage description.
    --version     Show version (%s).
""" % ( __db__, __version__ )

from datetime import datetime
import os
import re

import log
import script_util
import reporter
from taxus.init import SqlBase, get_session
from taxus import \
    Node, Name, Tag, Topic, Folder, GroupNode, \
    ID, Space, MaterializedPath, AdjacencyList, \
    ScriptMixin
import res.list

from sqlalchemy.orm import joinedload_all



metadata = SqlBase.metadata


# used by db_sa
models = [ Name, Tag, Topic, Folder ]

@reporter.stdout.register(Topic, [])
def format_Topic_item(topic):
    log.std(
"{blue}%s{bblack}. {bwhite}%s {bblack}[ about:{magenta}%s {bblack}] %s %s %s{default}" % (
                topic.topic_id,
                topic.path(),
                topic.super_id,

                str(topic.date_added).replace(' ', 'T'),
                str(topic.date_updated).replace(' ', 'T'),
                str(topic.date_deleted).replace(' ', 'T')
            )
        )


### Commands

def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

def cmd_list(settings):
    sa = Topic.get_session('default', settings.dbref)
    out = reporter.Reporter()
    assert out.get_context_path() == ('rst', 'paragraph')
    #out.start_list()
    #assert out.get_context_path() == ('rst', 'list')
    for t in Topic.all():
        if settings.paths:
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
    import sys
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


def cmd_x_tree(settings):
    """
    Adjacency list model
    """
    session = Topic.get_session('default', settings.dbref)
    def msg(msg, *args):
        msg = msg % args
        print("\n\n\n" + "-" * len(msg.split("\n")[0]))
        print(msg)
        print("-" * len(msg.split("\n")[0]))

    msg("Creating Tree Table:")

    node = Topic('rootnode')
    Topic('node1', super=node)
    Topic('node3', super=node)

    node2 = Topic('node2')
    Topic('subnode1', super=node2)
    node.subs['node2'] = node2
    Topic('subnode2', super=node.subs['node2'])

    msg("Created new tree structure:\n%s", node.dump())

    msg("flush + commit:")

    session.add(node)
    session.commit()

    msg("Tree After Save:\n %s", node.dump())

    Topic('node4', super=node)
    Topic('subnode3', super=node.subs['node4'])
    Topic('subnode4', super=node.subs['node4'])
    Topic('subsubnode1', super=node.subs['node4'].subs['subnode3'])

    # remove node1 from the super, which will trigger a delete
    # via the delete-orphan cascade.
    del node.subs['node1']

    msg("Removed node1.  flush + commit:")
    session.commit()

    msg("Tree after save:\n %s", node.dump())

    msg("Emptying out the session entirely, selecting tree on root, using "
        "eager loading to join four levels deep.")
    session.expunge_all()
    node = session.query(Topic).\
        options(joinedload_all("subs", "subs",
                               "subs", "subs")).\
        filter(Topic.name == "rootnode").\
        first()

    msg("Paths:\n%s", node.paths())
    #msg("Full Tree:\n%s", node.dump())

    msg("Marking root node as deleted, flush + commit:")

    session.delete(node)
    session.commit()


def cmd_x_mp(settings):
    """
    Example using materialized paths pattern.
    """
    session = MaterializedPath.get_session('default', settings.dbref)

    print("-" * 80)
    print("create a tree")
    session.add_all([
        MaterializedPath(id=1, path="1"),
        MaterializedPath(id=2, path="1.2"),
        MaterializedPath(id=3, path="1.3"),
        MaterializedPath(id=4, path="1.3.4"),
        MaterializedPath(id=5, path="1.3.5"),
        MaterializedPath(id=6, path="1.3.6"),
        MaterializedPath(id=7, path="1.7"),
        MaterializedPath(id=8, path="1.7.8"),
        MaterializedPath(id=9, path="1.7.9"),
        MaterializedPath(id=10, path="1.7.9.10"),
        MaterializedPath(id=11, path="1.7.11"),
    ])
    session.flush()
    print(str(session.query(MaterializedPath).get(1)))

    print("-" * 80)
    print("move 7 under 3")
    session.query(MaterializedPath).get(7).move_to(session.query(MaterializedPath).get(3))
    session.flush()
    print(str(session.query(MaterializedPath).get(1)))

    print("-" * 80)
    print("move 3 under 2")
    session.query(MaterializedPath).get(3).move_to(session.query(MaterializedPath).get(2))
    session.flush()
    print(str(session.query(MaterializedPath).get(1)))

    print("-" * 80)
    print("find the ancestors of 10")
    print([n.id for n in session.query(MaterializedPath).get(10).ancestors])

    session.commit()
    session.close()
    #SqlBase.metadata.drop_all(SqlBase.metadata.bind)


def cmd_x_al(settings):
    session = AdjacencyList.get_session('default', settings.dbref)

    def msg(msg, *args):
        msg = msg % args
        print("\n\n\n" + "-" * len(msg.split("\n")[0]))
        print(msg)
        print("-" * len(msg.split("\n")[0]))

    node = AdjacencyList('rootnode')
    AdjacencyList('node1', parent=node)
    AdjacencyList('node3', parent=node)

    node2 = AdjacencyList('node2')
    AdjacencyList('subnode1', parent=node2)
    node.children['node2'] = node2
    AdjacencyList('subnode2', parent=node.children['node2'])

    msg("Created new tree structure:\n%s", node.dump())

    msg("flush + commit:")

    session.add(node)
    session.commit()

    msg("Tree After Save:\n %s", node.dump())

    AdjacencyList('node4', parent=node)
    AdjacencyList('subnode3', parent=node.children['node4'])
    AdjacencyList('subnode4', parent=node.children['node4'])
    AdjacencyList('subsubnode1', parent=node.children['node4'].children['subnode3'])

    # remove node1 from the parent, which will trigger a delete
    # via the delete-orphan cascade.
    del node.children['node1']

    msg("Removed node1.  flush + commit:")
    session.commit()

    msg("Tree after save:\n %s", node.dump())

    msg("Emptying out the session entirely, selecting tree on root, using "
        "eager loading to join four levels deep.")
    session.expunge_all()
    node = session.query(AdjacencyList).\
        options(joinedload_all("children", "children",
                               "children", "children")).\
        filter(AdjacencyList.name == "rootnode").\
        first()

    msg("Full Tree:\n%s", node.dump())

    msg("Marking root node as deleted, flush + commit:")

    session.delete(node)
    session.commit()


"""
TODO: create item list from index, and vice versa uid:FEGl time:17:43Z

1. Parse list, like todo.txt
2. Keep db_sa SQLite
    1. Init db from list
    2. Update existing db from list
"""



### Transform cmd_ function names to nested dict

commands = script_util.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = script_util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'info'
    opts.flags.commit = not opts.flags.no_commit
    return script_util.run_commands(commands, settings, opts)

def get_version():
    return 'topic.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    opts = script_util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    opts.flags.dbref = os.getenv('TOPIC_DB', opts.flags.dbref)
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))

