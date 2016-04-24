#!/usr/bin/env python
"""
Javascript Object toolkit.

Usage:
    jsotk [options] path <srcfile> <expr>
    jsotk [options] [dump] [<srcfile> [<destfile]]
    jsotk [options] (json2yaml|yaml2json) [<srcfile> [<destfile]]
    jsotk [options] from-kv <args>...

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

Formats
-------
json
    ..
yaml
    ..
"""
import os, sys

from docopt import docopt

from script_mpe import util

from jsotk_lib import ArgvKeywordsParser, \
        load_data, stdout_data, readers


### Sub-command handlers

def H_dump(opts):
    outfile = None
    if opts.args.srcfile:
        infile = open(opts.args.srcfile)
        if 'destfile' in opts.args and opts.args.destfile:
            outfile = open(opts.args.srcfile)
    else:
        infile = sys.stdin
    if not outfile:
        outfile = sys.stdout
    data = load_data( opts.flags.input_format, infile )
    stdout_data( opts.flags.output_format, data, outfile, opts )

def H_yaml2json(opts):
    opts.flags.input_format = 'yaml'
    H_dump(opts)

def H_json2yaml(opts):
    opts.flags.output_format = 'yaml'
    H_dump(opts)

def H_path(opts):
    if opts.args.srcfile:
        if opts.args.srcfile is '-':
            infile = sys.stdin
        else:
            infile = open(opts.args.srcfile)
    data = readers[ opts.flags.input_format ]( infile )
    l = data
    path_el = opts.args.expr.split('.')
    while len(path_el):
        b = path_el.pop(0)
        if b not in l:
            raise KeyError, b
        l = l[b]
    print l

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

def H_from_kv(opts):
    args = opts.args.args
    data_obj = ArgvKeywordsParser(rootkey=args[0])
    data_obj.scan_kv_args(args)
    stdout_data( opts.flags.output_format, data_obj.data, sys.stdout, opts )



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
    sys.exit( main( opts.cmds[0], opts ) )


