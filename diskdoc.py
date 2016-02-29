#!/usr/bin/env python
"""
:created: 2016-02-22

Python helper to query/update disk metadatadocument 'disks.yaml'

Usage:
    projectdir-meta [options] list-disks

Options:
  --address ADDRESS
                The address that the socket server will be listening on. If
                the socket exists, any command invocation is relayed to the
                server intance, and the result output and return code
                returned to client. [default: /tmp/pd-serv.sock]
  --background  Turns script into socket server. This does not fork, detach
                or do anything else but enter an infinite server loop.
  -f DOC, --file DOC
                Give custom path to projectdir document file [default: ./projects.yaml]
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -g, --glob    Change from root prefix matching to glob matching.

Schema:

"""
import os
from fnmatch import fnmatch
from pprint import pformat
import subprocess

from docopt import docopt
import uuid
from deep_eq import deep_eq

from script_mpe import util, confparse
from script_mpe.res import js
from script_mpe.confparse import yaml_load, yaml_safe_dump


def yaml_commit(diskdata, ctx):
    yaml_safe_dump(diskdata, open(ctx.opts.flags.file, 'w+'), default_flow_style=False)


def H_list_disks(diskdata, ctx):
    """
    """

    mounts = subprocess.check_output('mount')
    #print 'Mounts', mounts

    devices = subprocess.check_output('find /dev/disk/by-uuid -type l'.split(' '))
    #print 'Devices', devices

    for id, attr in diskdata['catalog']['media'].items():
        print 'Disk', id
        # TODO: print when mounted
        for parts in attr['partitions']:
            for size, part in parts.items():
                if 'UUID' not in part:
                    print '  Incomplete data'
                    continue
                if part['UUID'] not in devices:
                    continue
                device = subprocess.check_output(['realpath',
                    '/dev/disk/by-uuid/'+part['UUID']]).strip()
                device = subprocess.check_output(['realpath',
                    '/dev/'+device]).strip()

                if device in mounts:
                    print '  Mounted:', size, device
                else:
                    print '  Available:', size, device


    #yaml_commit(diskdata, ctx)


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h

# XXX: no sessions
diskdata = None
def prerun(ctx, cmdline):
    global diskdata

    argv = cmdline.split(' ')
    ctx.opts = util.get_opts(ctx.usage, argv=argv)

    if not diskdata:
        diskdata = yaml_load(open(ctx.opts.flags.file))

    return [ diskdata ]


def main(ctx):

    """
    Run command, or start socket server.

    Normally this returns after running a single subcommand.
    If backgrounded, There is at most one server per projectdir
    document. The server remains in the working directory,
    and while running is used to resolve any calls. Iow. subsequent executions
    turn into UNIX domain socket clients in a transparent way, and the user
    command invocation is relayed via line-based protocol to the background
    server isntance.

    For projectdir document, which currently is 15-20kb, this setup has a
    minimal performance boost, while the Pd does not need
    to be loaded from and committed back to disk on each execution.

    """

    if ctx.opts.flags.background:
        localbg = __import__('local-bg')
        return localbg.serve(ctx, handlers, prerun=prerun)
    elif os.path.exists(ctx.opts.flags.address):
        localbg = __import__('local-bg')
        return localbg.query(ctx)
    elif 'exit' == ctx.opts.cmds[0]:
        print >>ctx.err, "No background process at %s" % ctx.opts.flags.address
        return 1
    else:
        diskdata = yaml_load(open(ctx.opts.flags.file))
        func = ctx.opts.cmds[0]
        assert func in handlers
        return handlers[func](diskdata, ctx)


if __name__ == '__main__':
    import sys
    ctx = confparse.Values(dict(
        usage=__doc__,
        out=sys.stdout,
        err=sys.stderr,
        inp=sys.stdin,
        opts=util.get_opts(__doc__)
    ))
    sys.exit( main( ctx ) )


