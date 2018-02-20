#!/usr/bin/env python
"""
:Created: 2017-04-17

Commands:
  - read-list
  - load-list
  - sync-list
  - write-list
  - update-list
  - x-rewrite-html-tree-id
  - glob
  - glob-read
  - memdebug
  - help [CMD]

  Database:
    - info | init | stats | clear
"""
from __future__ import print_function

__description__ = "list - manage lines representing records"
__short_description__ = "..."
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.list.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """
Usage:
  list.py [-v... options] read-list LIST [ PROVIDERS... ]
  list.py [-v... options] load-list LIST
  list.py [-v... options] sync-list LIST
  list.py [-v... options] write-list LIST [ PROVIDERS... ]
  list.py [-v... options] update-list LIST
  list.py [-v... options] x-rewrite-html-tree-id LIST
  list.py [-v... options] glob GLOBLIST
  list.py [-v... options] glob-read LIST
  list.py [-v... options] info | init | stats | clear
  list.py [-v... options] urllist [LIST]
  list.py [-v... options] memdebug
  list.py -h|--help
  list.py help [CMD]
  list.py --version

See `help` for usage per command.

Options:
  --filter-unmatched
                Reverse normal filter mode, where matched lines are returned
  --output-format FMT, -O FMT
                json, repr [default: json]
  --schema MOD
                Load models from given module, iso. using `lists`'s defaults
  --provider KEY=SPEC...
                Initialize projects or contexts API
  --apply-tag TAGSPEC...
                Apply given tags to each item in file
  --paths
                TODO: replace with --format=paths
  --match
                [default: item-id,hrefs,attr:unid]
  -d REF --dbref=REF
                SQLAlchemy DB URL [default: %s]
  --no-db       Don't initialize SQL DB connection
  --couch=REF
                Couch DB URL [default: %s]
  --no-commit   .
  --commit      [default: true]
  -v, --verbose
                Increase verbosity, 3 is maximum
  --quiet       ..
  --strict      ..
  -h --help     Show this usage description
  --version     Show version (%s)
""" % ( __db__, __couch__, __version__ )

import os
import sys
import re
import base64
from pprint import pformat
from fnmatch import fnmatch

from script_mpe.libhtd import *
#from taxus.v0 import Node, Name, ID, Topic, Outline



ctx = Taxus(version='bookmarks')

cmd_default_settings = dict(
        verbose=1,
        all_tables=True,
        database_tables=False,
        struct_output=False,
        no_couch=False,
    )


### Commands


def cmd_load_list(LIST, g):
    """
    Load items
    """
    g = defaults(g, res.list.list_parse_defaults, return_parser=True)
    prsr, items = res.list.parse(LIST, g)
    assert not 'TODO', "load items to where? ..."


def cmd_sync_list(LIST, g):
    """Update list for items found in a backend"""
    g = defaults(g, res.list.list_parse_defaults, return_parser=True)
    prsr, items = res.list.parse(LIST, g)
    assert not 'TODO', "update providers..."


def cmd_update_list(LIST, g, opts):

    """
    Update list with entries from stdin. This does not actually merge records,
    but checks that each input matches an existing list entry, or else appends
    one. Actual update modes to list entry fields are limited to ignore other
    data from input, or append input values iow. effectively merge matched
    items, or replace mode to overwrite existing entries with matches from input.

    Matching occurs on the record-id, urls and 'unid' attribute fields by
    default (see --match). Each item however is registered by its ID, updates
    without one will get appended with a blank id. The hrefs and unid matching
    serves to match with existing records, and apply the update mode instead.

    In ``--strict`` mode, Id mismatches, ie. two different Id's causes a new
    entry to be added regardless. (Existing ID's prefixed with _blank are
    regarded as blank and local only thus always overwritable if refs are kept
    consistent.)

    Manual merging may be required when duplicate field values are undesired.

    Use ``--force`` to override ID's from input, to merge based on match fields.
    Iow. require match field values to be unique. Conflicts with ``strict`` mode.

    TODO: list.py update-list work out above details
    """

    g = defaults(g, res.list.list_parse_defaults, return_parser=True)
    prsr, items = res.list.parse(LIST, g)
    prsr2, updates = res.list.parse(sys.stdin, g)
    opts.flags.match = opts.flags.split(',')
    new = {}
    # Modes to match items on input with LIST entries
    if 'item-id' in opts.flags.match:
        for u in updates:
            if not u.item_id:
                u.item_id = '_blank'+base64.urlsafe_b64encode(os.urandom(11))
            else:
                assert u.item_id in prsr2.records
            if u.item_id not in prsr.records:
                new[u.item_id] = u
    if 'hrefs' in opts.flags.match:
        for u in updates:
            if not u.hrefs: continue
            for href in u.hrefs:
                r = prsr.find_url(href)
                if r:
                    if u.item_id in new:
                        del new[u.item_id]
                else:
                    new[u.item_id] = u
                    break
    for m in opts.flags.match:
        if m .startswith('attr'):
            a = m[5:]
            for u in updates:
                if a not in u.attrs: continue
                for r in items:
                    if a not in r.attrs: continue
                    if u.attrs[a] == r.attrs[a]: break
                if not r or a not in r.attrs or u.attrs[a] != r.attrs[a]:
                    new.append(u)
    for u in new:
        prsr.handle_id(u, u.item_id)
    # Rewrite file
    w = res.list.ListTxtWriter(prsr)
    w.write(LIST)


def load_be_schema(settings):
    "Load schema and look for SQLAlchemy model names matching apply-contexts"
    if settings.schema:
        schema = __import__(settings.schema)
        models = schema.models
    else:
        models = [ Node, Name, ID, Topic, Outline ]
    for model in models:
        n = model.__name__
        if n in settings.apply_contexts:
            settings.be.sa_contexts[n] = model


def cmd_read_list(LIST, PROVIDERS, g):
    """
        Read items, resolving issues interactively and making sure items are
        committed to any backends.
    """
    global ctx
    #g.be = confparse.Values(dict(sa_contexts=dict()))
    #g.apply_contexts = [ c[1:] for c in PROVIDERS if c.startswith('@') ]
    #if g.apply_contexts:
    #    load_be_schema(g)
    #    log.std("Applying contexts %r" % g.apply_contexts)

    g = d.defaults(g, res.list.list_parse_defaults, return_parser=True)
    prsr, items = res.list.parse(LIST, g)
    prsr.proc( items )
    for it in items:
        print(str(it))
    return
    log.std("Processed %i items" % len(items))
    if g.commit:
        ctx.sa_session.commit()
        log.std("committed")


def cmd_write_list(LIST, PROVIDERS, g):
    """
        Retrieve all items from given backens and write to list file.
    """
    for provider in PROVIDERS:
        res.list.write(LIST, provider, g)


def run_glob_filter(input, glob_input, settings):
    globs = [ l.strip() for l in glob_input.readlines() if l.strip() ]
    def matched(p):
        for g in globs:
            if '*' in g or '?' in g or '[' in g:
                if fnmatch(p, g) or fnmatch(p, '*/'+g) or (
                    g[-1] is '/' and fnmatch(p, g+'*')
                ):
                    return True
            else:
                if '/'+g in p or g+'/' in p or p == g:
                    return True
    for line in input.readlines():
        line = line.strip()
        m = matched(line)
        if m and not settings.filter_unmatched:
            print(line)
        elif not m and settings.filter_unmatched:
            print(line)

def cmd_glob(GLOBLIST, g):
    """
        Filter lines on stdin by lines from glob-file. Default mode is to
        return matching lines. Set --filter-unmatched to inverse.
    """
    run_glob_filter(sys.stdin, open(GLOBLIST), g)


def cmd_glob_read(LIST, g):
    """
        Like glob, but read globs from stdin and lines from path on arguments.
    """
    run_glob_filter(open(LIST), sys.stdin, g)


re_key = re.compile("[%s]+" % mb.value_c)

def cmd_x_rewrite_html_tree_id(LIST, g):

    lines = open(LIST).readlines()
    stack = []
    for line in lines:
        if not line.strip() or line.strip().startswith('#'): continue
        id_indent = re.match('^:*', line).group()
        line = line[len(id_indent):].strip()
        key = None
        if ':' in line:
            key = line[:line.index(':')]
            if not re_key.match(key):
                log.warn("Invalid key %r format", key)
        if stack:
            while len(id_indent) <= len(stack):
                stack.pop()
        if stack:
            line += " [%s]" % stack[-1]
        if len(id_indent) > len(stack):
            if key:
                stack.append(key)
        print(line)


def cmd_urllist(LIST, g):
    global ctx

    prsr = res.list.URLListParser()
    l = list(prsr.load_file(LIST))
    if not l:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict: return 1

    #print(l)
    #print(prsr.items)
    ctx.lines_out(l)


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
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
    opts.flags.update(dict(
        commit = not opts.flags.no_commit,
        verbose = opts.flags.quiet and opts.flags.verbose or 1,
    ))
    opts.flags.update(dict(
        dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    ))
    return init

def main(opts):

    """
    Execute command.
    """
    global ctx, commands

    ctx.settings = settings = opts.flags
    settings.apply_contexts = {}
    ctx.init()

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'list.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    usage = __description__ +'\n\n'+ __short_description__ +'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'LIST_DB', __db__ ),
        ( 'COUCH_DB', __couch__ ) )

    db_sa.schema = sys.modules['__main__']
    db_sa.metadata = SqlBase.metadata

    opts = libcmd_docopt.get_opts(usage,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
