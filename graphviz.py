#!/usr/bin/env python
"""
:created: 2016-01-24

Python helper to query/update graphviz graph file.

Usage:
    graphviz.py [options] dump
    graphviz.py [options] print-info
    graphviz.py [options] print-graph-path
    graphviz.py [options] exit
    graphviz.py (--background|bg|background) [options]

Options:
  --address ADDRESS
                The address that the socket server will be listening on. If
                the socket exists, any command invocation is relayed to the
                server intance, and the result output and return code
                returned to client. [default: /tmp/gv-bg.sock]
  --background  Turns script into socket server. This does not fork, detach
                or do anything else but enter an infinite server loop.
  -f DOT, --file DOT
                Give custom path to graph document file [default: ./main.gv]
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -g, --glob    Change from root prefix matching to glob matching.

See projectdir-meta for context schema.
"""

import os
#from fnmatch import fnmatch
#from pprint import pformat

#import uuid
#from deep_eq import deep_eq

from script_mpe import util, confparse

import pydot



# Sub-command handlers

def H_dump(graph, ctx):
    pass

def H_print_info(graph, ctx):
    print 'Flags'
    print '  Socket', ctx.opts.flags.address
    print '  File', ctx.opts.flags.file

def H_print_graph_path(graph, ctx):
    print ctx.opts.flags.file


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h

graph = None
def prerun(ctx, cmdline):
    global graph

    argv = cmdline.split(' ')
    ctx.opts = util.get_opts(ctx.usage, argv=argv)

    if ctx.opts.cmds[0] in ( 'exit', ):
        return []

    if not graph:
        graph = pydot.graph_from_dot_file(ctx.opts.flags.file)

    return [ graph ]


def main(ctx):

    """
    Run command, or start socket server.
    """

    if ctx.opts.flags.background:
        bacground = __import__('local-bg')
        return bacground.serve(ctx, handlers, prerun=prerun)

    elif os.path.exists(ctx.opts.flags.address):
        bacground = __import__('local-bg')
        return bacground.query(ctx)

    elif 'exit' == ctx.opts.cmds[0]:
        print >>ctx.err, \
            "No background process at %s" % ctx.opts.flags.address
        return 1

    else:
        graph = pydot.graph_from_dot_file(ctx.opts.flags.file)
        func = ctx.opts.cmds[0]
        assert func in handlers
        return handlers[func](graph, ctx)


if __name__ == '__main__':
    import sys
    ctx = confparse.Values(dict(
        usage=__doc__,
        out=sys.stdout,
        err=sys.stderr,
        inp=sys.stdin,
        opts=util.get_opts(__doc__)
    ))
    if ctx.opts.cmds and ( ctx.opts.cmds[0] in ( 'background', 'bg' )):
        ctx.opts.flags.background = True
    sys.exit( main( ctx ) )

