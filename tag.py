#!/usr/bin/env python
""":created: 2015-12-28
:updated: 2014-10-12

"""
__description__ = ''
__version__ = '0.0.4-dev' #script-mpe
__db__ = '~/.topic.sqlite'
__usage__ = """
Anydbm tag index.

TODO: deprecate move functionality to db_sa.py based store [h2U_MT] and use
topics.py for now instead, or db.py if anydbm is a requirement

Usage:
  tag.py [options] insert <tag> [<label>]
  tag.py [options] drop <tag>
  tag.py [options] find <glob>
  tag.py [options] get <tag>
  tag.py [options] set <tags>...
  tag.py [options] [dump]

Options:
    -q, --quiet   Quiet operations
    -s, --strict  Strict operations
    -k, --key     Match (all) keys instead of tag labels.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    --new         Truncate DB
    --no-db       Set for some commands..
    -h --help     Show this usage description.
    --version     Show version (%s).


some ideas for commands::

    tags [options] rename <oldtag> <newtag>

    tags [options] relate <subj> <pred> <obj>

    tags [options] annotate <tag> <suffix> <value>

    tags [options] first-seen <tag> <date>
    tags [options] last-seen <tag> <date>
    tags [options] last-modified <tag> <date>

    tags [options] frequency <tag> <count>

    tags [options] set-url <tag> <url>
    tags [options] link <reltag> <tag> <tag>
    tags [options] prefer <preferredtag> <aliases>...
    tags [options] alias <tag> <aliases>...
    tags [options] abbrev <shorttag> <longtag>
    tags [options] group <containertag> <contained>...

Tag
    An ``[A-Za-z0-9_-]*`` string.
Glob
    See fnmatch stdlib.

""" % ( __db__, __version__ )
import os
import sys
import anydbm
import shelve
import re
from fnmatch import fnmatch

from script_mpe import util

from taxus.init import SqlBase, get_session
from taxus import \
    Node, Name, Tag, Topic, Folder, GroupNode, \
    ID, Space, MaterializedPath, \
    ScriptMixin


"""
XXX: may want some py-based subcmd back from
git:b7fc8a7f...0a38beae6ad2ab688e3f7f65afd6bd16:tags.py
but for db_sa this time.
Ie. processing with::

    tag_re = re.compile('[A-Za-z0-9_-]+')

See also db.py
"""

"""
TODO: create item list from index, and vice versa unid:FEGl time:17:43Z
See topic.py
"""



### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Main


def main(func=None, opts=None):

    if not opts.cmds:
        opts.cmds = ['dump']
    if not opts.flags.no_db:
        opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)

    settings = opts.flags

    if not opts.flags.no_db:
        db = Tag.get_session('default', opts.flags.dbref)
        assert db, "Not a DB: %s " % opts.flags.dbref
        settings.db = db

    return util.run_commands(commands, settings, opts)


def get_version():
    return 'tag.mpe/%s' % __version__

if __name__ == '__main__':
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit( main( opts.cmds[0], opts ) )

