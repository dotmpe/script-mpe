#!/usr/bin/env python
"""
Anydbm tag index.

Usage:
    tags [options] insert <tag> [<label>]
    tags [options] drop <tag>
    tags [options] find <glob>
    tags [options] get <tag>
    tags [options] [dump]

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -k, --key     Match (all) keys instead of tag labels.
  --db DBREF    Database path [default: ~/.script-tags.db]
  --new         Truncate DB

TODO: some ideas for commands::

    tags [options] rename <oldtag> <newtag>

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

"""
import os
import sys
import uuid
import anydbm
import shelve
import re
from fnmatch import fnmatch

from docopt import docopt

from script_mpe import util

from script_mpe.res import js
from script_mpe.confparse import yaml_load, yaml_safe_dump



def get_session(opts):
    "Get r/w session to existing or new DB"
    flag = opts.flags.new and 'n' or 'c'
    dbref = os.path.expanduser(opts.flags.db)
    return anydbm.open(dbref, flag)

tag_re = re.compile('[A-Za-z0-9_-]+')

class IllegalTagFormatException(Exception): pass

### Sub-command handlers

def H_insert(db, opts):
    if not tag_re.match( opts.args.tag ):
        raise IllegalTagFormatException(opts.args.tag)
    tk = "tag:%s" % opts.args.tag
    assert tk not in db, "Key exists %s" % tk
    if 'label' in opts.args:
        label = opts.args.label
    if not label:
        label = opts.args.tag
    db[tk] = label
    db.close()

def H_drop(db, opts):
    if not tag_re.match( opts.args.tag ):
        raise IllegalTagFormatException(opts.args.tag)
    tk = "tag:%s" % opts.args.tag
    assert tk in db, "No such key %s" % tk
    kv = (tk, db[tk])
    del db[tk]
    print "Dropped %s: '%s'" % kv
    db.close()

def H_get(db, opts):
    k = opts.args.tag
    if k in db:
        print k, db[k]
    else:
        return 1

def H_find(db, opts):
    for k, v in db.items():
        if opts.flags.key:
            if fnmatch(k, opts.args.glob):
                print k, v
        elif k.startswith('tag:') and fnmatch(v, opts.args.glob):
            print k, v

def H_dump(db, opts):
    for k, v in db.items():
        print k, v


### Main


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h


def main(func=None, opts=None):

    db = get_session(opts)

    return handlers[func](db, opts)


if __name__ == '__main__':
    opts = util.get_opts(__doc__)
    if not opts.cmds:
        opts.cmds = ['dump']
    sys.exit( main( opts.cmds[0], opts ) )



