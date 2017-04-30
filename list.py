#!/usr/bin/env python
""":created: 2017-04-17
"""
__description__ = "list - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.list.sqlite'
__usage__ = """
Usage:
  list.py [options] write-list LIST PROVIDERS...
  list.py [options] read-list LIST PROVIDERS...
  list.py [options] load-list LIST
  list.py [options] sync-list LIST
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

import confparse
import log
import script_util
from taxus.init import SqlBase, get_session
from taxus import Node, Name, ID, Topic, Outline, \
        ScriptMixin
import res.list
import res.task



def cmd_load_list(LIST, settings):
    """Read items, updating backends where found. """
    res.list.parse(LIST, settings)

def cmd_sync_list(LIST, settings):
    """Update list for items found in a backend"""
    res.list.parse(LIST, settings)


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
        print line


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
    return 'list.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    opts = script_util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    opts.flags.dbref = os.getenv('LIST_DB', opts.flags.dbref)
    opts.flags.dbref = ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))

