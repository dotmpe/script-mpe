#!/usr/bin/env python
""":created: 2017-04-17
"""
from __future__ import print_function

__description__ = "list - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.list.sqlite'
__usage__ = """
Usage:
  list.py [options] read-list LIST [ PROVIDERS... ]
  list.py [options] load-list LIST
  list.py [options] sync-list LIST
  list.py [options] write-list LIST [ PROVIDERS... ]
  list.py [options] update-list LIST
  list.py [options] x-rewrite-html-tree-id LIST
  list.py -h|--help
  list.py --version

Options:
    --output-format FMT
                  json, repr
    --schema MOD
                  Load models from given module, iso. using `lists`'s defaults.
    --provider KEY=SPEC...
                  Initialize projects or contexts API.
    --apply-tag TAGSPEC...
                  Apply given tags to each item in file.
    --paths
                  TODO: replace with --format=paths
    --match
                  [default: item-id,hrefs,attr:unid]
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    --no-commit   .
    --commit      [default: true].
    --verbose     ..
    --quiet       ..
    -h --help     Show this usage description.
    --version     Show version (%s).
""" % ( __db__, __version__ )

import os
import sys
import re
import base64

import confparse
import log
import libcmd_docopt
from taxus.init import SqlBase, get_session
from taxus import Node, Name, ID, Topic, Outline, \
        ScriptMixin
import res.list
import res.task



def cmd_load_list(LIST, settings):
    """Load items"""
    prsr, items = res.list.parse(LIST, settings)
    # XXX: sanity checks here iso. real unit tests
    for i in items:
        assert i.item_id in prsr.records
    assert not 'TODO', "load items to where? ..."

def cmd_sync_list(LIST, settings):
    """Update list for items found in a backend"""
    prsr, items = res.list.parse(LIST, settings)
    # XXX: sanity checks here iso. real unit tests
    for i in items:
        assert i.item_id in prsr.records
    assert not 'TODO', "update providers..."

def cmd_update_list(LIST, settings, opts):
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
    prsr, items = res.list.parse(LIST, settings)
    prsr2, updates = res.list.parse(sys.stdin, settings)
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

def cmd_read_list(LIST, PROVIDERS, settings):
    """Read items, resolving issues interactively and making sure items are
    committed to any backends. """
    session = ScriptMixin.get_session('default', settings.dbref)
    settings.be = confparse.Values(dict(sa_contexts=dict()))
    settings.apply_contexts = [ c[1:] for c in PROVIDERS if c.startswith('@') ]
    if settings.apply_contexts:
        load_be_schema(settings)
        log.std("Applying contexts %r" % settings.apply_contexts)
    prsr, items = res.list.parse(LIST, settings)
    prsr.proc( items )
    log.std("Processed %i items" % len(items))
    if settings.commit:
        session.commit()
        log.std("committed")

def cmd_write_list(LIST, PROVIDERS, settings):
    """Retrieve all items from given backens and write to list file. """
    for provider in PROVIDERS:
        res.list.write(LIST, provider, settings)


re_key = re.compile("[%s]+" % res.task.value_c)

def cmd_x_rewrite_html_tree_id(LIST, settings):
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


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    opts.default = 'info'
    opts.flags.commit = not opts.flags.no_commit
    settings = opts.flags
    settings.apply_contexts = []
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'list.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    opts = libcmd_docopt.get_opts(__description__ + '\n' + __usage__, version=get_version())
    opts.flags.dbref = os.getenv('LIST_DB', opts.flags.dbref)
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
