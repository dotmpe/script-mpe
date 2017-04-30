#!/usr/bin/env python
"""
:created: 2016-01-24

Python helper to query/update graphviz graph file.

Usage:
    graphviz.py [options] dump
    graphviz.py [options] get-node NODE
    graphviz.py [options] add-node NODE [ATTRS...]
    graphviz.py [options] update-node NODE ATTRS...
    graphviz.py [options] get-node-attr NODE ATTR
    graphviz.py [options] add-edge NODE_FROM NODE_TO [ATTRS...]
    graphviz.py [options] set-simplify BOOL
    graphviz.py [options] print-info
    graphviz.py [options] print-graph-path
    graphviz.py [options] print-socket-name
    graphviz.py [options] exit
    graphviz.py (--background|bg|background) [options]

Options:
  --dump        After sub command has run, dump file to stdout.
  --no-commit   Don't save file on exit.
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

from script_mpe import script_util, confparse

import pydot


def kv_to_dict( *kwdargs ):
    new = dict()
    new.update(dict([ k.split('=') for k in kwdargs if k ]))
    for k,v in new.items():
        if isinstance(v, str):
            if v.lower() == 'true':
                v = True
            elif v.lower() == 'false':
                v = False
            elif v.isdigit():
                v = int(v)
    return new



# Sub-command handlers

def H_dump(graph, ctx):
    graphstr = graph.to_string()
    print graphstr


def H_print_info(graph, ctx):
    print 'Opts'
    print '  Flags'
    print '    Socket', ctx.opts.flags.address
    print '    File', ctx.opts.flags.file
    if graph:
        print 'Graph'
        print '  Edges',
        print graph.get_edge_list()
        #print graph.get_edges()
        print '  Nodes',
        print graph.get_node_list()
        #print graph.get_nodes()
        print '  Subgraphs',
        print graph.get_subgraph_list()


def H_print_graph_path(graph, ctx):
    print ctx.opts.flags.file

def H_print_socket_name(graph, ctx):
    print ctx.opts.flags.address


def H_add_edge(g, ctx):
    attr = kv_to_dict(*ctx.opts.args.ATTRS)
    edge = pydot.Edge(
            ctx.opts.args.NODE_FROM,
            ctx.opts.args.NODE_TO,
            **attr
        )
    g.add_edge(edge)
    ctx.dirty = True


def H_get_node(g, ctx):
    name = ctx.opts.args.NODE
    node = graph.get_node(name)
    if isinstance(node, list) and len(node) == 0:
        if not ctx.opts.flags.quiet:
            print >>ctx.err, "No node", name
        if ctx.opts.flags.strict or not ctx.opts.flags.quiet:
            return 1
    print node

def H_add_node(g, ctx):
    attr = kv_to_dict(*ctx.opts.args.ATTRS)
    node = pydot.Node(
            ctx.opts.args.NODE,
            **attr
        )
    g.add_node(node)
    ctx.dirty = True

def H_update_node(g, ctx):
    attr = kv_to_dict(*ctx.opts.args.ATTRS)
    name = ctx.opts.args.NODE
    node = g.get_node(name)
    for k, v in attr.items():
        node.set(k, v)
    ctx.dirty = True

def H_get_node_attr(g, ctx):
    name = ctx.opts.args.NODE
    node = g.get_node(name)
    attr = ctx.opts.args.ATTR
    print node.get(attr)


def H_set_simplify(g, ctx):
    # no double edges
    if ctx.opts.args.bool.lower() in ( "0", "no", "false" ):
        g.set_simplify( False )
    else:
        g.set_simplify( True )


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h

graph = None
def prerun(ctx, cmdline):
    global graph

    argv = cmdline.split(' ')
    ctx.opts = script_util.get_opts(ctx.usage, argv=argv)

    if ctx.opts.cmds[0] in ( 'exit', ):
        return []

    if not graph:
        graph = pydot.graph_from_dot_file(ctx.opts.flags.file)

    return [ graph ]


def postrun(ctx, ret):
    global graph

    if ctx.opts.flags.dump:
        graphstr = graph.to_string()
        print graphstr

    if graph and not ret and not ctx.opts.flags.no_commit:
        if ctx.dirty:
            graphstr = graph.to_string()
            open(ctx.opts.flags.file, 'w+').write( graphstr )
            print >>ctx.err, 'Saved to', ctx.opts.flags.file
        del graph


def main(ctx):

    """
    Run command, or start socket server.
    """

    global graph

    if ctx.opts.flags.background:
        background = __import__('local-bg')
        return background.serve(ctx, handlers, prerun=prerun, postrun=postrun)

    elif os.path.exists(ctx.opts.flags.address):
        background = __import__('local-bg')
        return background.query(ctx)

    elif 'exit' == ctx.opts.cmds[0]:
        print >>ctx.err, \
            "No background process at %s" % ctx.opts.flags.address
        return 1

    else:
        graph = pydot.graph_from_dot_file(ctx.opts.flags.file)
        func = ctx.opts.cmds[0]
        assert func in handlers
        x = handlers[func](graph, ctx)
        postrun(ctx, x)
        return x


if __name__ == '__main__':
    import sys
    ctx = confparse.Values(dict(
        usage=__doc__,
        out=sys.stdout,
        err=sys.stderr,
        inp=sys.stdin,
        opts=script_util.get_opts(__doc__),
        dirty=False
    ))
    if ctx.opts.cmds and ( ctx.opts.cmds[0] in ( 'background', 'bg' )):
        ctx.opts.flags.background = True
    sys.exit( main( ctx ) )


