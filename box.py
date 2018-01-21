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
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -g, --glob    Change from root prefix matching to glob matching.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).
""" % __version__

import os

from script_mpe import libcmd_docopt, confparse


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

def H_dump(script, ctx):
    #attr = kv_to_dict(*ctx.opts.args.ATTRS)
    #print(attr)
    print(script)
    print(ctx)


def H_info(ctx):
    print('Opts')
    print('  Flags')
    print('    Socket', ctx.opts.flags.address)
    print('    Exists', os.path.exists(ctx.opts.flags.address))
    print('    File', ctx.opts.flags.file)


def H_set_file(ctx):
    pass


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'H_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug,
))



script = None

def prerun(ctx, cmdline):
    global script

    argv = cmdline.split(' ')
    ctx.opts = libcmd_docopt.get_opts(ctx.usage, argv=argv)

    if ctx.opts.cmds[0] in ( 'exit', ):
        return []

    # TODO: setup script
    script = 'foo'

    return [ script ]

def postrun(ctx):
    #if ctx.opts.flags.dump:
    pass


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
        #pdhdata = yaml_load(open(ctx.opts.flags.file))
        func = ctx.opts.cmds[0]
        assert func in commands
        return commands[func](ctx)



if __name__ == '__main__':
    import sys
    ctx = confparse.Values(dict(
        short=__short_description__ ,
        description=__description__ ,
        usage=__usage__ ,
        out=sys.stdout,
        err=sys.stderr,
        inp=sys.stdin,
        opts=libcmd_docopt.get_opts(__usage__),
        dirty=False
    ))
    if ctx.opts.cmds and ( ctx.opts.cmds[0] in ( 'background', 'bg' )):
        ctx.opts.flags.background = True
    sys.exit( main( ctx ) )
