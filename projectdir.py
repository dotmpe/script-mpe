#!/usr/bin/env python
"""projectdir -
:Created: 2017-11-23
:Updated: 2017-12-09

TODO: integrate with projectdir-meta, but need to update libs, tooling first.
Which in turn also requires revising projectdir.sh. Building out while keeping
compatible.
"""
from __future__ import print_function

__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.taxus-code.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """

Usage:
  projectdir.py [options] ( list | tab )
  projectdir.py [options] ( stat | update | delete | find | check
        | show
        | catalog
        | list-scmdirs
        | find-untracked
        ) [ <refs>... ]
  projectdir.py sync <doc>
  projectdir.py validate [ <doc> ]
  projectdir.py -h|--help|help
  projectdir.py --version

Options:
  -s, --strict    Be more conservative, and abort directly on errors.
  -q, --quiet     Implies strict, and turns off verbosity.
  --older-than SPEC
                  [default: 1day]
  --pretty-doc    ..
  --ignored
                  Include ignored/excluded files in output.
  --interactive
  --categorize
  --normalize-remotes
  --couch=REF     Couch DB URL [default: %s]
  -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
  --no-db         Don't initialize SQL DB connection.
  -h --help       Show this usage description.
                  For a command and argument description use the command 'help'.
  --version       Show version (%s).

""" % ( __couch__, __db__, __version__ )
__doc__ += __usage__

import os
from itertools import chain
from pprint import pprint

from script_mpe import libcmd_docopt, log, taxus, res, lib, confparse, datelib

from libcmd_docopt import cmd_help
from taxus import Taxus, v0, ScriptMixin
from taxus.init import SqlBase, get_session
from res import Workdir, Repo, Homedir
from res.dt import modified_before, older_than
from taxus.v0 import Node, Topic, Host, Project, VersionControl
from pdlib import *
from jsotk_lib import deep_update


### A few more globals

models = [ Project, VersionControl ]

ctx = Taxus(version='projectdir')

cmd_default_settings = dict(
        no_strict_types=False,
        list_update=False,
        list_update_nodict=True,
        list_union=True
    )


### CLI Subcommands

def cmd_list(g):

    """
    List SCM dirs from project doc.
    """
    global ctx

    ctx.ws = Workdir.require()
    ctx.ws.yamldoc('pdoc', defaults=dict(repositories={}))
    for prefix in ctx.ws.pdoc['repositories']:
        print(prefix)


def cmd_tab(g):
    global ctx
    ctx.ws.yamldoc('pdoc', defaults=dict(repositories={}))
    for prefix in ctx.ws.pdoc['repositories']:
        repo = ctx.ws.pdoc['repositories'][prefix]
        print(prefix+':')
        if 'remotes' not in repo or not repo['remotes']:
            continue
        for remote in repo['remotes']:
            print('  '+remote['name']+': '+remote['url'])


def cmd_show(refs, g):

    """
    Print records for given prefixes.
    """
    global ctx
    ws = ctx.ws

    s = g.quiet
    if not refs:
        refs = ctx.ws.pdoc['repositories'].keys()

    os.chdir(ws.path)
    out_ = {}
    for r in refs:
        prefix = ws.relpath(r)
        if prefix not in ctx.ws.pdoc['repositories']:
            log.stderr("No such prefix %r" % r)
            if g.strict: return 1
        if g.strict and not os.path.exists(prefix):
            log.stderr("Prefix does not exist %r" % r)
            return 1
        repo = ctx.ws.pdoc['repositories'][prefix]
        out_[prefix] = confparse.yaml_flatten(repo)

    confparse.yaml_dump(sys.stdout, out_,
            ignore_aliases=False,
            default_flow_style=False)


def cmd_sync(doc, g):

    """
    """

    global ctx
    ws = ctx.ws
    updated = False

    for prefix in ctx.ws.pdoc['repositories']:
        repo = ws.pdoc['repositories'][prefix]
        print(prefix, repo)

    if updated:
        ws.yamlsave('pdoc', default_flow_style=not g.pretty_doc)


def cmd_validate(doc, g):
    global ctx
    if not doc:
        doc = ctx.ws.get_yaml('pdoc')
    lib.cmd(["htd", "validate-pdoc", doc])


def cmd_catalog(refs, g):
    global ctx
    ws = ctx.ws
    s = g.quiet
    updated = False

    os.chdir(ws.path)
    if refs:
        log.stderr('Filtering on %s' % (', '.join(refs)))
        pathiter = chain( *[ws.find_scmdirs(ref, s=s) for ref in refs ] )
    else:
        pathiter = ws.find_scmdirs(s=s)

    for p in pathiter:
        if os.path.islink(p): continue
        prefix = ws.relpath(p)
        repo = ws.pdoc['repositories'][prefix]
        updated = catalog(prefix, repo, g)

    if updated:
        ws.yamlsave('pdoc', default_flow_style=not g.pretty_doc)


def cmd_update(refs, opts, g):

    """
    Without arguments, update for entire workspace. Finds local SCM dirs, and
    ensure a pdoc record each exists. Record is created or updated from
    `htd info`. Only prefixes older-than are updated, set to 0 to update all.
    """
    global ctx
    ws = ctx.ws
    s = g.quiet
    updated = 0

    os.chdir(ws.path)
    if refs:
        log.stderr('Filtering on %s' % (', '.join(refs)))
        pathiter = chain( *[ws.find_scmdirs(ref, s=s) for ref in refs ] )
    else:
        pathiter = ws.find_scmdirs(s=s)

    for p in pathiter:
        if os.path.islink(p): continue
        prefix = ws.relpath(p)

        if prefix not in ws.pdoc['repositories'] or (
            older_than( ws.pdoc['repositories'][prefix]['(date)'], g.older_than )
        ):
          log.stderr("Updating %r" % prefix)
          cmd = "htd info '%s'" % p
          out = lib.cmd(cmd, allowerrors=True)
          data = confparse.yaml_loads(out)
          if prefix in ws.pdoc['repositories']:
              deep_update( [ws.pdoc['repositories'][prefix], data],
                      confparse.Values(dict(opts=opts)))
          else:
              ws.pdoc['repositories'][prefix] = data

        if g.categorize:
          # Add type and ID
          repo = ws.pdoc['repositories'][prefix]
          if catalog(prefix, repo, g):
              updated += 1

        if g.normalize_remotes:
          data = ws.pdoc['repositories'][prefix]
          cmd = "htd remote ... '%s'" % p
          # TODO: use htd to get latest remote urls, catch up on renames
          for remote in repo['remotes']:
              print(remote['name'], remote['url'])

    ws.yamlsave('pdoc', default_flow_style=not g.pretty_doc,
        ignore_aliases=True)
    log.stderr("%i prefixes OK (%s old at most)",
            len(ws.pdoc['repositories'].keys()), g.older_than)


def cmd_delete(refs, g):

    """
    Delete prefixes from project doc.
    """
    global ctx
    s = g.quiet

    if not refs: return  1
    for r in refs:
        if r not in ctx.ws.pdoc['repositories']:
            log.stderr("No such prefix %r" % r)
            if g.strict: return 1
        del ctx.ws.pdoc['repositories'][r]

    ctx.ws.yamlsave('pdoc', default_flow_style=not g.pretty_doc)


def cmd_check(refs, g):

    """
    See that ID and type for projects is set.

    TODO: check with registry too unless offline.
    """
    global ctx

    s = g.quiet
    if not refs:
        refs = ctx.ws.pdoc['repositories'].keys()

    for r in refs:
        if r not in ctx.ws.pdoc['repositories']:
            log.stderr("No such prefix %r" % r)
            if g.strict: return 1
        if g.strict and not os.path.exists(r):
            log.stderr("Prefix does not exist %r" % r)
            return 1
        repo = ctx.ws.pdoc['repositories'][r]
        if 'id' in repo and repo['id']:
            if not g.strict or ( 'type' in repo and repo['type']):
                log.stderr("Prefix missing type %r" % r)
                if not g.strict or ( 'vendor' in repo and repo['vendor']):
                    log.stderr("Prefix missing vendor %r" % r)
                continue
        else:
            log.stderr("Prefix missing ID %r" % r)

        if g.strict: return 1


def cmd_list_scmdirs(refs, g):

    """
    List versioned dirs.
    """
    global ctx
    s = True

    if refs:
        pathiter = chain( *[ctx.ws.find_scmdirs(ref, s=s) for ref in refs ] )
    else: pathiter = ctx.ws.find_scmdirs(s=s)

    for p in pathiter:
        if os.path.islink(p): continue
        print(ctx.ws.relpath(p))


def cmd_find_untracked(refs, settings):

    """
    List untracked files. Use --ignored to include ignored files.

    TODO: clean Workdir().find_untracked API, flexible backends.
    Ie. match symlinks.tab entries.
    """

    repo = Repo.fetch()
    if repo:
        cwd = os.path.realpath('.')
        assert cwd.startswith(repo.path)
        if settings.ignored:
            for p in repo.excluded():
                if not cwd or p.startswith(cwd):
                    print(p)
        else:
            for p in repo.untracked():
                if not cwd or p.startswith(cwd):
                    print(p)
        return

    ws = ctx.ws
    if not ws:
        ws = Homedir.fetch()
    if ws:
        if settings.ignored:
            list(ws.find_excluded('.'))
        else:
            list(ws.find_untracked('.'))
        return

    log.stderr("Not a workspace or checkout dir")
    return 1


def cmd_stat(refs, settings):

    """
    TODO: list dirty files.
    """


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
    opts.flags.update(
        dbref = ScriptMixin.assert_dbref(opts.flags['dbref'])
    )
    # XXX: how trigger on user-args? strict=opts.flags.quiet
    return init

def main(opts):

    """
    Execute command.
    """
    global ctx, commands

    ws = Workdir.require()
    ws.yamldoc('pdoc', defaults=dict(
            repositories={},
            last_sync=None
        ))
    ctx.ws = ws

    # Can safely replace ctx.settings too since defaults() has integrated it
    ctx.settings = settings = opts.flags
    ctx.init()
    # XXX: opts.default = 'find'

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    global __version__
    return 'projectdir.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    argv = sys.argv[1:]
    if not argv: argv = [ 'list' ]
    usage = libcmd_docopt.static_vars_from_env(__doc__,
        ( 'PROJECT_DB', __db__ ),
        ( 'COUCH_DB', __couch__ ) )

    opts = libcmd_docopt.get_opts(usage, version=get_version(), argv=argv,
            defaults=defaults)
    sys.exit(main(opts))
