#!/usr/bin/env python
"""
:Created: 2017-08-19

Commands:
  - todolist - TODO.txt format parser
  - urllist - annotated URL list
  - doctree
  - memdebug
  - help [CMD]
"""
from __future__ import print_function
__description__ = "txt - "
__version__ = '0.0.4-dev' # script-mpe
#__db__ = '~/.txt.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """
Usage:
  txt.py [-v... options] urllist LIST
  txt.py [-v... options] doctree [LIST] [DIR]
  txt.py [-v... options] [ LIST | todolist [LIST] ]
  txt.py [-v... options] memdebug
  txt.py -h|--help
  txt.py help [CMD]
  txt.py --version

Options:
  -O FMT, --output-format FMT
                json, json-stream, str, repr [default: json-stream]
  --couch=REF   Couch DB URL [default: %s]
  --verbose     ..
  --quiet       ..
  -h --help     Show this usage description
  --version     Show version (%s)
""" % ( __couch__, __version__ )
import os
from itertools import chain

from script_mpe.libhtd import *


ctx = taxus.Taxus(version=None)

cmd_default_settings = dict(
        strict=False,
        struct_output=False
    )


def cmd_urllist(LIST, g):
    prsr = res.list.URLListParser()
    l = list(prsr.load_file(LIST))
    g.tp = 'locator'
    for i in l:
        ctx.out(i)
    ctx.flush()

def cmd_todolist(LIST, g):
    # TODO: extend new res.txt2 parser base
    prsr = res.todo.TodoListParser()
    l = list(prsr.load_file(LIST))
    g.tp = 'todo'
    for i in l:
        ctx.out(i)
    ctx.flush()
    return

    prsr = res.todo.TodoTxtParser()
    LIST = LIST or 'todo.txt'
    list(prsr.load(LIST))
    for k, o in prsr.items():
        #print(o.todotxt())
        #print(res.js.dumps(prsr[k].attrs))
        ctx.out(o)
    ctx.flush()

def cmd_doctree(LIST, DOCS, g):

    """
    TODO: assemble cross-format index: docs, python modules, etc.
    """

    global ctx

    LIST = LIST or '-'
    if not DOCS: DOCS = ['.']

    docid = ctx.ws.id_path + '.catalog'
    if docid in ctx.docs:
        catalog = couch.catalog.Catalogdoc.load(ctx.docs, name)

    else:
        catalog = couch.catalog.Catalogdoc()
    #catalog = ctx.yamldoc('catalog', defaults=[])
    #catalog = ctx.ws.yamldoc('catalog', defaults=[])

    pathiters = [ ctx.ws.find_docs(ref, strict=g.strict) for ref in DOCS ]
    for path in chain(*pathiters):

        basedir = os.path.dirname(path)
        basename = os.path.basename(path)
        name, extpart = os.path.splitext(basename)

        if basename in catalog:
            o = catalog[basename]
            if 'type' in o:
                type_ = o['type']
                if type_ is not 'document':
                    raise ValueError("Unknown document type at %s" % basename)

            del catalog[basename]

        if name in catalog:
            o = catalog[name]
            if 'type' in o:
                type_ = o['type']
                if type_ is not 'document':
                    raise ValueError("Unknown document type at %s" % name)

        else:
            o = dict(
                path=path,
                name=name,
                type='document'
            )

            # Find neighbars at the same basename
            at_base = ctx.ws.neighbours(os.path.join(basedir, name))
            variants = [ os.path.splitext(p)[1][1:] for p in at_base ]

            at_base = ctx.ws.find_names(os.path.join(basedir, name), 'bin')
            #variants.extend([ os.path.splitext(p)[1][1:] for p in at_base ])
            variants.extend([ p for p in at_base ])

            while extpart[1:] in variants:
                variants.remove(extpart[1:])

            # And names in other dirs too.. but setup proper project ctx for that
            if variants:
                log.stderr("Variants for %s (from %s)" % (name, path))
                continue # print(name, variants)

            catalog[name] = o
            ctx.out(o)

    #catalog.store(ctx.docs)
    ctx.flush()


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug
    ))


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    ctx.settings.update(opts.flags)
    opts.flags.update(ctx.settings)

    return init

def main(opts):

    """
    Execute command.
    """

    ws = res.Workdir.require()
    ctx.ws = ws
    ctx.settings = settings = opts.flags
    ctx.init()

    opts.default = 'todolist'
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    global __version__
    return 'txt.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    usage = __description__ +'\n\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'COUCH_DB', __couch__ ) )

    opts = libcmd_docopt.get_opts(usage, version=get_version(), defaults=defaults)
    sys.exit(main(opts))
