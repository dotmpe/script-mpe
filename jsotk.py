#!/usr/bin/env python
"""
jsotk
=====
Javascript Object toolkit
~~~~~~~~~~~~~~~~~~~~~~~~~

:created: 2015-12-28
:updated: 2016-05-21


"""
from __future__ import print_function

__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
jsotk - Javascript Object toolkit

Usage:
    jsotk [options] path [--is-new] [--is-null] [--is-list] [--is-obj]
            [--is-int] [--is-str] [--is-bool] <srcfile> <pathexpr>
    jsotk [options] objectpath <srcfile> <expr>
    jsotk [options] keys <srcfile> <pathexpr>
    jsotk [options] items <srcfile> <pathexpr>
    jsotk [options] (json2yaml|yaml2json) [<srcfile> [<destfile>]]
    jsotk [options] (from-kv|to-kv) [<srcfile> [<destfile>]]
    jsotk [options] (from-flat-kv|to-flat-kv) [<srcfile> [<destfile>]]
    jsotk [options] from-args <kv_args>...
    jsotk [options] from-flat-args <fkv-args>...
    jsotk [options] merge-one <srcfile> <srcfile2> [<destfile>]
    jsotk [options] merge <destfile> <srcfiles>...
    jsotk [options] append <destfile> <pathexpr> [<srcfiles>...]
    jsotk [options] update <destfile> [<srcfiles>...]
    jsotk [options] update-from-args <srcfiles> <kv-args> <destfile>
    jsotk [options] update-at <destfile> <expr> [<srcfiles>...]
    jsotk (version|-V|--version)
    jsotk (help|-h|--help)
    jsotk [options] [dump] [<srcfile> [<destfile]]
    jsotk --background [options]


Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -p, --pretty  Pretty output formatting.
  -I <format>, --input-format <format>
                Override input format. See Formats_.
                TODO: default is to autodetect from filename
                if given, or set to [default: json].
  -O <format>, --output-format <format>
                Override output format. See Formats_.
                TODO: default is to autodetect from filename
                if given, or set to [default: json].
  --no-indices  [default: false]
  --detect-format
  --no-detect-format
                Auto-detect input/output format based on file-name extension
                [default: true]
  --output-prefix PREFIX
                Path prefix for output [default: ]
  --list-update
                .
  --list-update-nodict
                .
  --list-union
                .
  --no-stdin
                .
  -N, --empty-null
                Instead of null, print empty line.
  --line-input
                Parse input lines separately.
                Only with merge JSON.
  --background  Turns script into socket server. This does not actually fork,
                detach or do anything else but enter an infinite server loop:
                use shell job control to background it.
  -S, --address ADDRESS
                The address that the socket server will be listening on for a
                backgrounded process. This defaults to JSOTK_SOCKET, and
                creates one if '--background' is requested. [default: /tmp/jsotk-serv.sock]
                .
                If the socket exists, any command invocation is relayed to the
                "server" instance, and the result output and return code
                returned to client. This python client process is less efficient
                as using a socket client from a shell script.
                .
                If no ADDRESS or JSOTK_SOCKET is found the invocation is
                executed normally
  -V, --version
                Print version

Formats
-------
json (i/o)
    ..
yaml (i/o)
    ..
pkv
    Parse syntax like::

        path/to[1]/item=value-for-object-path
        path/to[]=append-item-value

    To::

        {"path": {"to": [ {"item": "value-for-object-path"}, "append-item-value" ] } }

fkv (o)
    Like pkv, but this is even more restrictive in key characters, keys
    can only contain [A-Za-Z_][A-Za-z0-9_]+ and everything else is lost.
    Still the (example at pkv) above can be represented, for example::

        path_to__1_item=value-for-object-path
        path_to__2=append-item-value

    Double underscores are used to separate path elements.
py (o)
    Given one or more results, output as python value.
lines (o)
    Given a list result, simply output items line by line.

Dev
----
- Functions seem to be behaving, but need a bit of refactoring to make the
  arguments more consistent and clear. Maybe need to ditch docopt.
- Background is a work in progress, file input buffering and parsed structure
  caching needs to be added. jsotk (Sh) frontend is not in use yet.
- Another improvement may be seeking out SHM filesystem support.

"""
import types
from StringIO import StringIO

from objectpath import Tree


import script_util, confparse
from jsotk_lib import PathKVParser, FlatKVParser, \
        load_data, stdout_data, readers, open_file, \
        get_src_dest_defaults, set_format, get_format_for_fileext, \
        get_dest, get_src_dest, \
        deep_union, deep_update, data_at_path, data_check_path, maptype



### Sub-command handlers

# Conversions, json is default format

def H_dump(ctx, write=True):
    "Read src and write destfile according to set i/o formats. "
    infile, outfile = get_src_dest_defaults(ctx)
    data = load_data( ctx.opts.flags.input_format, infile, ctx )
    if write:
        return stdout_data( data, ctx, outf=outfile )
    else:
        return data


def H_merge_one(ctx):
    "Docopt does not handle args for 'merge', so instead use this. "
    ctx.opts.args.srcfiles = [ ctx.opts.args.srcfile, ctx.opts.args.srcfile2 ]
    H_merge(ctx)


def H_merge(ctx, write=True):
    """Merge srcfiles into last file. All srcfiles must be same format.
    Defaults to src-to-dest noop, iow. '- -' functions identical to
    'dump'.  """

    if not ctx.opts.args.srcfiles and not ctx.opts.flags.line_input:
        ctx.opts.args.srcfile = '-'
        return H_dump(ctx, write=write)

    if ctx.opts.flags.line_input:
        ctx.opts.args.srcfile = ctx.opts.args.srcfiles.pop(0)
        set_format('input', 'src', ctx.opts)
        inp = open_file(ctx.opts.args.srcfile, 'in', ctx=ctx)
        ctx.opts.args.srcfiles += [ StringIO(line) for line in inp.readlines() ]
    else:
        ctx.opts.args.srcfile = ctx.opts.args.srcfiles[0]
        set_format('input', 'src', ctx.opts)


    if not (ctx.opts.flags.list_union or ctx.opts.flags.list_update):
        if ctx.opts.flags.list_update_nodict:
            ctx.opts.flags.list_update = True
        else:
            ctx.opts.flags.list_union = True

    data = None
    for srcfile in ctx.opts.args.srcfiles:
        mdata = None
        if hasattr(srcfile, 'read'):
            infile = srcfile
        elif isinstance(srcfile, (dict, list)):
            mdata = srcfile
            srcfile = '<inline>'
            infile = None
        else:
            infile = open_file(srcfile, defio='in', ctx=ctx)
        if infile and not mdata:
            mdata = load_data( ctx.opts.flags.input_format, infile, ctx )
        if not data:
            data = type(mdata)()
        elif not isinstance(mdata, type(data)):
            raise ValueError, "Srcsfiles must have same root type. "\
                    "Expected %s, but found %s (%s)" % (
                            type(data), type(mdata), srcfile )
        if isinstance(data, dict):
            deep_update([data, mdata], ctx)
        elif isinstance(data, list):
            data = deep_union([data, mdata], ctx)
        else:
            raise ValueError, data

    if write:
        outfile = open_file(ctx.opts.args.destfile, mode='w+', ctx=ctx)
        return stdout_data( data, ctx, outf=outfile )
    else:
        return data


def H_append(ctx):
    "Add srcfiles as items to list. Optionally provide pathexpr to list. "
    if not ctx.opts.args.srcfiles:
        return
    appendfile = get_dest(ctx, 'r')
    data = l = load_data( ctx.opts.flags.output_format, appendfile, ctx )
    if ctx.opts.args.pathexpr:
        l = data_at_path(ctx, None, data)
    for src in ctx.opts.args.srcfiles:
        fmt = get_format_for_fileext(src) or ctx.opts.flags.input_format
        mdata = load_data( fmt, open_file( src, 'in', ctx=ctx ), ctx )
        l.append(mdata)
    updatefile = get_dest(ctx, 'w+')
    return stdout_data( data, ctx, outf=updatefile )


def H_update(ctx):
    "Update srcfile from stdin. Write to destfile or stdout. "

    if not ctx.opts.args.srcfiles:
        return

    updatefile = get_dest(ctx, 'r')
    data = load_data( ctx.opts.flags.output_format, updatefile, ctx )
    updatefile.close()

    for src in ctx.opts.args.srcfiles:
        fmt = get_format_for_fileext(src) or ctx.opts.flags.input_format
        mdata = load_data( fmt, open_file( src, 'in', ctx=ctx ), ctx )

        deep_update([data, mdata], ctx)

    updatefile = get_dest(ctx, 'w+')
    return stdout_data( data, ctx, outf=updatefile )


def H_update_from_args(ctx):
    print('TODO')
    pass
    # TODO jsotk update-from-args
    #reader = PathKVParser(rootkey=args[0])
    #reader.scan_kv_args(ctx.opts.args.kv_args)


def H_update_at(ctx):
    """Update object at path, using data read from srcfile(s)"""
    if not ctx.opts.args.srcfiles:
        return
    updatefile = get_dest(ctx, 'r')
    data = o = load_data( ctx.opts.flags.output_format, updatefile, ctx )
    #if ctx.opts.args.pathexpr:
        #o = data_at_path(ctx, None, data)
    if ctx.opts.args.expr:
        q = Tree(data)
        assert q.data
        o = q.execute( ctx.opts.args.expr )
    if isinstance(o, types.GeneratorType):
        r = list(o)
        assert len(r) == 1, r
        o = r[0]
        #r = [ stdout_data( s, ctx, outf=sys.stdout) for s in o ]
        #print(r)
    for src in ctx.opts.args.srcfiles:
        fmt = get_format_for_fileext(src) or ctx.opts.flags.input_format
        mdata = load_data( fmt, open_file( src, 'in', ctx=ctx ), ctx )
        deep_update([o, mdata], ctx)
    updatefile = get_dest(ctx, 'w+')
    return stdout_data( data, ctx, outf=updatefile )



# Ad-hoc designed path query

def H_path(ctx):

    """
    Return data at path. Return 1 if path is not found. Use with ``--is-*``
    opts to OR-test for type or exit 2. To check if a path could be inserted,
    use ``--is-new``. This overrules not-found errors, but only if the path
    could be inserted. When any existing
    element does not match a list or object type it also exits non-zero.
    """

    infile, outfile = get_src_dest_defaults(ctx)
    data = None
    try:
        data = data_at_path(ctx, infile)
        infile.close()
    except (Exception) as e:
        if not ctx.opts.flags.is_new:
            if not ctx.opts.flags.quiet:
                sys.stderr.write("Error: getting %r: %r" % (
                    ctx.opts.args.pathexpr, e ))
            return 1

    res = [ ]

    for tp in "new list obj int str bool".split(" "):
        if ctx.opts.flags["is_%s" % tp]:
            # FIXME: print(maptype(tp))
            if tp == "new":
                infile, outfile = get_src_dest_defaults(ctx)
                if not data and data_check_path(ctx, infile):
                    res += [ 0 ]
            elif isinstance(data, maptype(tp)):
                res += [ 0 ]
            else:
                res += [ 1 ]

    if res and min(res) == 0:
        res = [ 0 ]

    if not ctx.opts.flags.quiet:
        res += [ stdout_data( data, ctx, outf=outfile ) ]

    return max(res)


def H_keys(ctx):
    "Output list of keys or indices"
    infile, outfile = get_src_dest_defaults(ctx)
    try:
        data = data_at_path(ctx, infile)
    except:
        return 1
    if not data:
        return 1
    if isinstance(data, dict):
        return stdout_data( data.keys(), ctx, outf=outfile )
    elif isinstance(data, list):
        return stdout_data( range(0, len(data)), ctx, outf=outfile )
    else:
        raise ValueError, "Unhandled type %s" % type(data)

def H_items(ctx):
    "Output for every key or item in object at path"
    infile, outfile = get_src_dest_defaults(ctx)
    try:
        data = data_at_path(ctx, infile)
    except:
        return 1
    if not data:
        return 1
    if isinstance(data, list):
        for item in data:
            stdout_data( item, ctx, outf=outfile )
    elif isinstance(data, dict):
        for key, value in data.items():
            subdata = { key: value }
            stdout_data( subdata, ctx, outf=outfile )
    else:
        raise ValueError, "Unhandled type %s" % type(data)



def H_objectpath(ctx):
    infile, outfile = get_src_dest_defaults(ctx)
    data = load_data( ctx.opts.flags.input_format, infile, ctx )
    assert data
    q = Tree(data)
    assert q.data
    o = q.execute( ctx.opts.args.expr )
    if isinstance(o, types.GeneratorType):
        for s in o:
            v = stdout_data( s, ctx, outf=outfile )
            if v:
                return v
    else:
        return stdout_data( o, ctx, outf=outfile )



# TODO: helper for plain text (parser-less) updates to YAML/JSON

def H_offsets(ctx):
    """
    TODO: could print offsets from yaml.tokens.*.start/end_mark

    Print source offsets in line/column and absolute characters
    for
        --keys
        --list-items

    mloatk offsets --key redmine --list-items
    mloatk offsets --path redmine.image --value
    mloatk offsets --path redmine.image --value

    """


## Conversion shortcuts


def H_yaml2json(ctx):
    ctx.opts.flags.input_format = 'yaml'
    return H_dump(ctx)

def H_json2yaml(ctx):
    ctx.opts.flags.output_format = 'yaml'
    return H_dump(ctx)


# Flat key-value from/to nested list/dicts

def H_from_args(ctx):
    args = ctx.opts.args.kv_args
    reader = PathKVParser(rootkey=args[0])
    reader.scan_kv_args(args)
    return stdout_data( reader.data, ctx )

def H_from_kv(ctx):
    ctx.opts.flags.input_format = 'pkv'
    return H_dump(ctx)

def H_to_kv(ctx):
    ctx.opts.flags.output_format = 'pkv'
    return H_dump(ctx)


def H_from_flat_args(ctx):
    args = ctx.opts.args.fkv_args
    reader = FlatKVParser(rootkey=args[0])
    reader.scan_kv_args(args)
    return stdout_data( reader.data, ctx )

def H_from_flat_kv(ctx):
    ctx.opts.flags.input_format = 'fkv'
    return H_dump(ctx)

def H_to_flat_kv(ctx):
    ctx.opts.flags.output_format = 'fkv'
    return H_dump(ctx)



def H_version(ctx):
    print('script-mpe/'+__version__)



### Main


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h


doc_cache = None
def prerun(ctx, cmdline):
    global doc_cache

    argv = cmdline.split(' ')
    ctx.opts = script_util.get_opts(ctx.usage, argv=argv)

    #if not pdhdata:
    #    pdhdata = yaml_load(open(ctx.opts.flags.file))

    return doc_cache


def main(func, ctx):

    """
    Run command, or start socket server.

    Normally this returns after running a single subcommand.
    If backgrounded, There is at most one server per jsotk
    document. The server remains in the working directory,
    and while running is used to resolve any calls. Iow. subsequent executions
    turn into UNIX domain socket clients in a transparent way, and the user
    command invocation is relayed via line-based protocol to the background
    server isntance.

    """

    if ctx.opts.flags.background:
        # Start background process
        localbg = __import__('local-bg')
        return localbg.serve(ctx, handlers, prerun=prerun)

    elif ctx.path_exists(ctx.opts.flags.address):
        # Query background process
        localbg = __import__('local-bg')
        return localbg.query(ctx)

    elif 'exit' == ctx.opts.cmds[0]:
        # Exit background process
        ctx.err.write("No background process at %s\n" % ctx.opts.flags.address)
        return 1

    else:
        # Normal execution
        return handlers[func](ctx)



if __name__ == '__main__':
    import sys, os
    if sys.argv[-1] == 'help':
        sys.argv[-1] = '--help'
    ctx = confparse.Values(dict(
        usage=__usage__,
        path_exists=os.path.exists,
        sep=confparse.Values(dict(
            line=os.linesep
        )),
        out=sys.stdout,
        inp=sys.stdin,
        err=sys.stderr,
        opts=script_util.get_opts(__usage__)
    ))
    ctx['in'] = ctx['inp']
    if ctx.opts.flags.version:
        ctx.opts.cmds = ['version']
    if not ctx.opts.cmds:
        ctx.opts.cmds = ['dump']
    if ctx.opts.flags.no_detect_format:
        ctx.opts.flags.detect_format = False
    else:
        ctx.opts.flags.detect_format = True
    # TODO: ctx.opts.flags.no_json_string
    try:
        sys.exit( main( ctx.opts.cmds[0], ctx ) )
    except Exception as err:
        if not ctx.opts.flags.quiet:
            import traceback
            tb = traceback.format_exc()
            print(tb)
            print('Unexpected Error:', err)
        sys.exit(1)

