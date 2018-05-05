#!/usr/bin/env python
"""
:Created: 2018-01-20

Python helper to parse/write box script files

"""
from __future__ import print_function

__short_description__ = 'box - parse/write box script files'
__description__ = __doc__
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Usage:
    box.py [options] dump
    box.py [options] info
    box.py [options] specs [ - | SPECS... ]
    box.py [options] exit
    box.py (--background|bg|background) [options]
    box.py [options] help [CMD]
    box.py -h|--help
    box.py --version

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
  -f SH, --file SH
                Script file
  --pretty
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -g, --glob    Change from root prefix matching to glob matching.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).
""" % __version__

import os

from script_mpe import libcmd_docopt, confparse


cmd_default_settings = dict(
        output_prefix=None,
        ignore_aliases=True,
        cleanup_attr=['_i']
    )


# Sub-command handlers

def H_dump(script, ctx):
    print(script)
    print(ctx)


def H_info(script, ctx):
    print('Opts')
    print('  Flags')
    print('    Socket', ctx.opts.flags.address)
    print('    Exists', os.path.exists(ctx.opts.flags.address))
    print('    File', ctx.opts.flags.file)


### Box Sh specs
# TODO: parse complete spec JSON from given scripts,
# output HTML docs from template, map local and global references

def parse_spec(line , ctx):
    l = line.strip()
    parts = l.split(' # ')
    f = parts.pop(0)

    if f.endswith('{'): f = f[:-1].strip()
    if f.endswith('()'):
        r = dict(name=f[:-2], type='func')

    elif '=' in f:
        i = f.index('=')
        vn, v = f[:i], f[i+1:]
        r = dict(name=vn, value=v, type='var')

    else:
        assert False, (l, f, parts[0])

    if parts:
        assert len(parts) == 1, line
        r['comment'] = parts[0]

    return r


def parse_base_type(specs, r, ctx):
    n = r['name']
    if '__' in n:
        p = n.split('__')
        r['base'] = p[0]

        if len(p) >= 2:
            if r['type'] in ('func', 'var'):
                r['subcmd'] = p[1].replace('_', '-')
                r['type'] = 'subcmd'

        if len(p) < 3: pass
        elif len(p) == 3:
            r['action'] = p[2:]
        elif len(p) == 4:
            r['context'], r['action'] = p[2:]
        else:
            assert False, r

    return r

def parse_spec_id(specs, r, ctx):
    if 'id' not in r:
        assert r['name'] not in specs, r['name']
        r['id'] = r['name']

def finish_spec(specs, r, ctx):
    for k in ctx.opts.flags.cleanup_attr:
        if k in r:
            del(r[k])


from jsotk_lib import yaml_writer

def H_specs(script, ctx):
    """
    Parse specs.
    """
    if ctx.opts.args.SPECS:
        specs = ctx.opts.args.SPECS
    else:
        specs = sys.stdin.readlines()

    data = []
    for line in specs:
        data.append( parse_spec(line, ctx) )
        data[-1]['_i'] = len(data)-1

    specdoc = {}
    for spec in data:
        parse_base_type(specdoc, spec, ctx)
        if 'id' not in spec:
            parse_spec_id(specdoc, spec, ctx)
        specdoc[spec['id']] = spec

    for spec in data:
        finish_spec(specdoc, spec, ctx)

    yaml_writer(specdoc, sys.stdout, ctx)


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'H_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug,
))



### Service global(s) and setup/teardown handlers

script = None

def setup_script(ctx):
    global script

    # TODO: setup script
    script = ctx.opts.flags.file

def prerun(ctx, cmdline):
    global script

    argv = cmdline.split(' ')
    ctx.opts = libcmd_docopt.get_opts(ctx.usage, argv=argv)

    if ctx.opts.cmds[0] in ( 'exit', ):
        return []

    setup_script(ctx)

    return [ script ]

def postrun(ctx):
    pass


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)

    return init

def main(ctx):

    """
    Run command, or start socket server.
    """

    if ctx.opts.flags.background:
        # Start background process
        localbg = __import__('local-bg')
        if not ctx.opts.flags.quiet:
            print("Starting background server at", ctx.opts.flags.address)
        return localbg.serve(ctx, commands, prerun=prerun, postrun=postrun)

    elif os.path.exists(ctx.opts.flags.address):
        # Query background process
        localbg = __import__('local-bg')
        return localbg.query(ctx)

    elif 'exit' == ctx.opts.cmds[0]:
        # Exit background process
        ctx.err.write("No background process at %s\n" % ctx.opts.flags.address)
        return 1

    else:
        # Normal execution
        func = ctx.opts.cmds[0]
        assert func in commands
        setup_script(ctx)
        return commands[func](script, ctx)
        # TOOD: further intialize (global) context, ie. kwdarg_aliases
        #return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'box/%s' % __version__



if __name__ == '__main__':
    import sys
    ctx = confparse.Values(dict(
        short=__short_description__ ,
        description=__description__ ,
        usage=__usage__ ,
        opts=libcmd_docopt.get_opts(__usage__,
            version=get_version(), defaults=defaults)
    ))
    if ctx.opts.flags.version: ctx.opts.cmds = ['version']
    if not ctx.opts.cmds: ctx.opts.cmds = ['dump']
    if ctx.opts.cmds and ( ctx.opts.cmds[0] in ( 'background', 'bg' )):
        ctx.opts.flags.background = True
    sys.exit( main( ctx ) )
