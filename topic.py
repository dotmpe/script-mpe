#!/usr/bin/env python
""":created: 2014-09-07

TODO: create all topics; name, description, hierarchy and dump/load json/xml
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
    -h --help     Show this screen.
    --version     Show version (%s).
""" % ( __db__, __version__ )

from datetime import datetime
import os
import re

import log
import util
from taxus.init import SqlBase, get_session
from taxus import \
    Node, Name, Tag, Topic


metadata = SqlBase.metadata


def cmd_info(settings):
    for l, v in (
            ( 'DBRef', settings.dbref ),
            ( "Tables in schema", ", ".join(metadata.tables.keys()) ),
    ):
        log.std('{green}%s{default}: {bwhite}%s{default}', l, v)

def cmd_list(settings):
    sa = Topic.get_session('default', settings.dbref)
    for t in Topic.all():
        print t

def cmd_new(NAME, REF, settings):
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

def cmd_get(REF, settings):
    sa = Topic.get_session('default', settings.dbref)
    print Topic.byKey(dict(topic_id=REF))
    print Topic.byName(REF)


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags

    # FIXME: share default dbref uri and path, also with other modules
    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    opts.default = 'info'

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'bookmarks.mpe/%s' % __version__

if __name__ == '__main__':
    #bookmarks.main()
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))


