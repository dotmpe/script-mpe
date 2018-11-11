#!/usr/bin/env python
"""
:Created: 2017-08-19

Commands:
  - todolist - TODO.txt format parser
  - urllist - annotated URL list
  - doctree - annotate text documents
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
  txt.py [-v... options] doctree [LIST] [DIR...]
  txt.py [-v... options] ( fold OUTLINE [LIST] | unfold LIST [OUTLINE] )
  txt.py [-v... options] [ LIST | todolist [LIST] ]
  txt.py [-v... options] todotxt TXT
  txt.py [-v... options] txtstat-tree [STAT]
  txt.py [-v... options] proc LIST
  txt.py [-v... options] memdebug
  txt.py -h|--help
  txt.py help [CMD]
  txt.py --version

Options:
  -O FMT, --output-format FMT
                json, json-stream, str, repr [default: json-stream]
  --couch=REF   Couch DB URL [default: %s]
  --print-names
  --print-paths
  --unique-names
                ..
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
    prsr = res.lst.URLListParser()
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

def cmd_todotxt(TXT, g):
    prsr = res.todo.TodoTxtParser()
    TXT = TXT or 'todo.txt'
    list(prsr.load(TXT))
    for o in prsr.items():
        #print(o.todotxt())
        #print(res.js.dumps(prsr[k].attrs))
        ctx.out(o)
    ctx.flush()

def cmd_proc(LIST, g):
    prsr = res.lst.ListTxtParser()



def cmd_doctree(LIST, DIR, g):

    """
    Go over files in DIR, get all document files.

    TODO: construct topic tree,
    sync update catalog, couchdoc and/or LIST
    """
    global ctx

    if LIST and os.path.isdir(LIST):
        DIR.append(LIST)
        LIST = None
    if not DIR: DIR = ['.']

    where_names = "main index readme".split(' ')

    catalog = res.doc.Catalog.load(ctx)
    log.stderr("Updating catalog at %s" % (ctx.ws.full_path,))
    pathiters = [ ctx.ws.find_docs(ref, strict=g.strict) for ref in DIR ]
    for path in chain(*pathiters):
        basedir, name, extpart = fs.basepathparts(path)
        basename = name+extpart

        if not os.path.getsize(path):
            log.stderr("Ignored empty file %r" % (path))
            continue

        if name.lower() in where_names:
            name = os.path.basename(basedir)
            if name in catalog:
                continue # XXX: skipping duplicate dir where-files index/ReadMe/main

        if name in catalog:
            catalog.verify_docentry(name, path)
            continue

        if name.lower() in where_names:
            o = catalog.new_direntry(name, path)
        else:
            o = catalog.new_docentry(name, path)

        if g.print_names:
            if o['type'] == 'directory':
                print(o['name']+'/')
            else:
                print(o['name'])
            #ctx.output_buffer.append(['name'])

        elif g.print_paths:
            print(o['path'])

        else:
            ctx.out(o)

        """
        if g.unique_names:
            # Find all of the same basename (at this dir)
            at_base = ctx.ws.find_names(name)
        else:
            # Find neighbours at the same basename
            at_base = ctx.ws.neighbours(os.path.join(basedir, name))
        variants = [ os.path.splitext(p)[1][1:] for p in at_base ]
        print(variants)
        while extpart[1:] in variants:
            variants.remove(extpart[1:])
        """

    ctx.flush()
    catalog.save(ctx)


def cmd_txtstat_tree(STAT, g):
    """
    """
    print(STAT)


### Box fold outline

def cmd_fold(OUTLINE, LIST, g):
    """
    TODO: Parse nested plain text format.
    """
    import scrow
    from scrow.resolve import resolve
    from scrow.aparse import indented_blocks

	# TODO: remove ctx from scrow API
    cstream, null = resolve(ctx, False)

    lines = scrow.translit.Lines()
    lines.read(cstream)

    linespans = list(lines.iter_spans())
    indent = list(indented_blocks(lines.data, linespans, ctx))


def cmd_unfold(LIST, OUTLINE, g):
    """
    TODO: Parse LIST and reformat as indented OUTLINE text.

    Items are grouped by tag expressions, see options below. The groups are
    output in sequence with the arguments, earlier selector options win from
    later selectors. As last the un-selected entries are output un-indented.

    -t, --term TERMS
        One or more terms of tag or tags. Selected entries must contain each tag.
        XXX: use literal match on raw entry fields, maybe glob/re things
        XXX: to output a subset, use path-expr <Tag>/<Tag>

        -t @Dev -t @Dev/@Script

        with path-expr the first -t becomes obsolete, but the basepath redundant
        ie. -t @Dev/@Script -t @Dev/@Flow

        bash can solve this, if we change from option to arguments ::

            @Dev/{@Script,@Flow}

    -j '[{"@Dev":[{"@Dev/@Script"

        maybe allow a JSON expr, but that is cumbersome

    XXX: without arguments maybe build tree from topics.
    """
    pass


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
    global ctx

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
