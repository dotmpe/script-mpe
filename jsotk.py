#!/usr/bin/env python
"""
Javascript Object toolkit.

Usage:
    jsotk [options] path <srcfile> <expr>
    jsotk [options] [dump] [<srcfile> [<destfile]]
    jsotk [options] (json2yaml|yaml2json) [<srcfile> [<destfile]]

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

from script_mpe.res import js
from script_mpe.confparse import yaml_load, yaml_safe_dump



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

    data = readers[ opts.flags.input_format ]( infile )
    writers[ opts.flags.output_format ]( data, outfile, opts )

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



### Readers/Writers

readers = dict(
        json=js.load,
        yaml=yaml_load
    )


def json_writer(data, file, opts):
    kwds = {}
    if opts.flags.pretty:
        kwds.update(dict(indent=2))
    file.write(js.dumps(data, **kwds))

def yaml_writer(data, file, opts):
    kwds = {}
    if opts.flags.pretty:
        kwds.update(dict(default_flow_style=False))
    yaml_safe_dump(data, file, **kwds)

writers = dict(
        json=json_writer,
        yaml=yaml_writer
    )


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


