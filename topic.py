#!/usr/bin/env python
""":created: 2014-09-07
:updated: 2014-10-12

TODO figure out model. look at folder.py first.
TODO: create all nodes; name, description, hierarchy and dump/load json/xml
    most dirs in tree ~/htdocs/
    headings in ~/htdocs/personal/journal/*.rst
    files in ~/htdocs/note/*.rst
"""
__description__ = "topic - "
__version__ = '0.0.0'
__db__ = '~/.topic.sqlite'
__usage__ = """
Usage:
  topic.py [options] [info|list]
  topic.py [options] (name|tag|topic|host|domain) [NAME]
  topic.py [options] new NAME [REF]
  topic.py [options] get REF
  topic.py -h|--help
  topic.py --version

Options:
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

import log
import util
import reporter
from taxus.init import SqlBase, get_session
from taxus import \
    Node, Name, Tag, Topic, Folder, \
    ScriptMixin


metadata = SqlBase.metadata


# used by db_sa
models = [ Name, Tag, Topic, Folder ]

@reporter.stdout.register(Topic, [])
def format_Topic_item(topic):
    log.std(
"{blue}%s{bblack}. {bwhite}%s {bblack}[ about:{magenta}%s {bblack}] %s %s %s{default}" % (
                topic.topic_id,
                topic.name,
                topic.about_id,

                str(topic.date_added).replace(' ', 'T'),
                str(topic.last_updated).replace(' ', 'T'),
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
        reporter.stdout.Topic(t)
        #out.print_item(t)
    out.finish()

def cmd_new(NAME, REF, settings):
    #store = Topic.start_master_session()
    #print store
    #topic = store.Topic.byName(NAME)
    #if topic:
    #    pass
    #else:
    #    topic = store.Topic.forge(name=NAME)
    #    store.commit()
    #reporter.stdout.Topic(topic)

    # XXX: old 
    sa = Topic.get_session('default', settings.dbref)
    topic = Topic.byName(NAME)
    if topic:
        log.std("Found existing topic %s, created %s", topic.name,
                topic.date_added)
    else:
        topic = Topic(name=NAME)
        topic.init_defaults()
        sa.add(topic)
        sa.commit()
        log.std("Added new topic %s", topic.name)
    reporter.stdout.Topic(topic)

def cmd_get(REF, settings):
    sa = Topic.get_session('default', settings.dbref)
    topic = Topic.byKey(dict(topic_id=REF))
    reporter.stdout.Topic(topic)
    topic = Topic.byName(REF)
    reporter.stdout.Topic(topic)


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = 'info'
    return util.run_commands(commands, settings, opts)

def get_version():
    return 'topic.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))


