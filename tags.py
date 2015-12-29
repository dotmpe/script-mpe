#!/usr/bin/env python
"""
Anydbm tag index.

Usage:
    tags [options] insert <tag> [<label>]
    tags [options] drop <tag>
    tags [options] find <glob>
    tags [options] get <tag>
    tags [options] set <tags>...
    tags [options] [dump]

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -k, --key     Match (all) keys instead of tag labels.
  --db DBREF    Database path [default: ~/.script-tags.db]
  --new         Truncate DB


TODO: some ideas for commands::

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

class NoSuchTagException(Exception): pass
class IllegalTagFormatException(Exception): pass

### Sub-command handlers

def H_insert(db, opts):
    """
    Insert and print tag key.
    """
    if not tag_re.match( opts.args.tag ):
        raise IllegalTagFormatException(opts.args.tag)
    tk = "tag:%s" % opts.args.tag
    assert tk not in db, "Key exists %s" % tk
    if 'label' in opts.args:
        label = opts.args.label
    if not label:
        label = opts.args.tag
    tkl = "tag:%s:label" % opts.args.tag
    db[tk] = ''
    db[tkl] = label
    db.close()
    print tk

def H_drop(db, opts):
    """
    Drop by tag key.
    """
    if not tag_re.match( opts.args.tag ):
        raise IllegalTagFormatException(opts.args.tag)
    tk = "tag:%s" % opts.args.tag
    assert tk in db, "No such key %s" % tk
    tkl = "tag:%s:label" % opts.args.tag
    kv = (tk, db[tkl])
    del db[tkl]
    del db[tk]
    print kv
    db.close()

def H_get(db, opts):
    """
    Find one by matching tag to tag:%s key.
    """
    k = "tag:%s" % opts.args.tag
    if k in db:
        print opts.args.tag, db["%s:label" % k]
    else:
        return 1

def H_find(db, opts):
    """
    Find by matching value.
    """
    for k, v in db.items():
        if opts.flags.key:
            if fnmatch(k, opts.args.glob):
                print k, v
        elif k.startswith('tag:') and fnmatch(v, opts.args.glob):
            print k, v

def H_set(db, opts):
    """
    Create or extend tag:%s:set list for each
    and assert that set `<tags>...` exists.
    Each tag must exist. XXX: each set does contain the assigned tag as well.
    """
    new_set = set(opts.args.tags)
    for tag in opts.args.tags:
        k = "tag:%s" % tag
        if k not in db:
            raise NoSuchTagException(tag)
        tags = get_tag_set(db, tag)
        if not ( tags > new_set ):
            updated = tags.union(new_set)
            set_tag_set(db, tag, updated)
            print tag, ','.join(updated)

def get_tag_set(db, tag):
    ks = "tag:%s:set" % tag
    if ks in db:
        return set( db[ks].split('\0') )
    return set()

def set_tag_set(db, tag, tags):
    ks = "tag:%s:set" % tag
    db[ks] = '\0'.join(tags)

def H_dump(db, opts):
    """
    Dump db keys.
    """
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


