#!/usr/bin/env python
"""
Javascript Object toolkit.

Usage:
    jsotk [options] path <srcfile> <expr>
    jsotk [options] objectpath <srcfile> <expr>
    jsotk [options] [dump] [<srcfile> [<destfile]]
    jsotk [options] (json2yaml|yaml2json) [<srcfile> [<destfile>]]
    jsotk [options] (from-kv|to-kv) [<srcfile> [<destfile>]]
    jsotk [options] (from-flat-kv|to-flat-kv) [<srcfile> [<destfile>]]
    jsotk [options] from-args <args>...
    jsotk [options] from-flat-args <args>...

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

Formats
-------
json
    ..
yaml
    ..
"""
import os, sys
import types

from docopt import docopt
from objectpath import Tree

from script_mpe import util

from jsotk_lib import PathKVParser, \
        load_data, stdout_data, readers, \
        get_src_dest_defaults


### Sub-command handlers

# Conversions, json is default format

def H_dump(opts):
    infile, outfile = get_src_dest_defaults(opts)
    data = load_data( opts.flags.input_format, infile )
    stdout_data( opts.flags.output_format, data, outfile, opts )

def H_yaml2json(opts):
    opts.flags.input_format = 'yaml'
    H_dump(opts)

def H_json2yaml(opts):
    opts.flags.output_format = 'yaml'
    H_dump(opts)

# Ad-hoc designed path query

def H_path(opts):
    infile, outfile = get_src_dest_defaults(opts)
    l = load_data( opts.flags.input_format, infile )
    path_el = opts.args.expr.split('.')
    while len(path_el):
        b = path_el.pop(0)
        if b not in l:
            raise KeyError, b
        l = l[b]
    print l

def H_objectpath(opts):
    infile, outfile = get_src_dest_defaults(opts)
    q = Tree(load_data( opts.flags.input_format, infile ))
    o = q.execute( opts.args.expr )
    if isinstance(o, types.GeneratorType):
        for s in o:
            stdout_data( opts.flags.output_format, s, outfile, opts )
    else:
        stdout_data( opts.flags.output_format, o, outfile, opts )



# TODO: helper for plain text (parser-less) updates to YAML/JSON

def H_offsets(opts):
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


# Flat key-value from/to nested list/dicts

def H_from_args(opts):
    args = opts.args.args
    reader = PathKVParser(rootkey=args[0])
    reader.scan_kv_args(args)
    stdout_data( opts.flags.output_format, reader.data, sys.stdout, opts )

def H_from_kv(opts):
    opts.flags.input_format = 'pkv'
    H_dump(opts)

def H_to_kv(opts):
    opts.flags.output_format = 'pkv'
    H_dump(opts)

def H_from_flat_kv(opts):
    opts.flags.input_format = 'fkv'
    H_dump(opts)

def H_to_flat_kv(opts):
    opts.flags.output_format = 'fkv'
    H_dump(opts)


### Main


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h


def main(func=None, opts=None):

    return handlers[func](opts)


if __name__ == '__main__':
    opts = util.get_opts(__doc__)
    if not opts.cmds:
        opts.cmds = ['dump']
    if opts.flags.no_detect_format:
        opts.flags.detect_format = False
    else:
        opts.flags.detect_format = True
    sys.exit( main( opts.cmds[0], opts ) )


