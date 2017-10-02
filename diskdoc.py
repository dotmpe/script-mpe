#!/usr/bin/env python
"""
:created: 2016-02-22

Python helper to query/update disk metadatadocument 'disks.yaml'

Usage:
    diskdoc.py [options] disks
    diskdoc.py [options] list-disks

Commands:
    disks
        Show local disks.
    list-disks
        ..

Options:
  --address ADDRESS
                The address that the socket server will be listening on. If
                the socket exists, any command invocation is relayed to the
                server intance, and the result output and return code
                returned to client. [default: /tmp/pd-serv.sock]
  --background  Turns script into socket server. This does not fork, detach
                or do anything else but enter an infinite server loop.
  -f DOC, --file DOC
                Give custom path to projectdir document file [default: ~/.conf/disk/mpe.yaml]
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -g, --glob    Change from root prefix matching to glob matching.
  --exclude-mount MOUNT
  --include-mount MOUNT
  --exclude-device DEVICE
  --include-device DEVICE
                Filter by device node, exclude devices not in list.
  --include-fstype TYPES
  --exclude-fstype TYPES
                Default behaviour is to ignore given types.
                [default: proc sysfs rootfs cgroup mqueue tmpfs pstore fusectl devpts devtmpfs autofs hugetlbfs securityfs rpc_pipefs fuseblk debugfs]
  --include-fstype TYPES
                Override ignore-fstype, and ignore every filesystem type not in
                given list. [default: ]
"""
import os
import re
from fnmatch import fnmatch
from pprint import pformat
import subprocess

from docopt import docopt
import uuid
from deep_eq import deep_eq

from script_mpe import libcmd_docopt, confparse
from script_mpe.res import js
from script_mpe.confparse import yaml_load, yaml_safe_dump



def yaml_commit(diskdata, ctx):
    yaml_safe_dump(diskdata, open(ctx.opts.flags.file, 'w+'), default_flow_style=False)


ws_collapse_re = re.compile('\s+')
collapse_ws = lambda s:ws_collapse_re.subn(' ', s)[0]

def readtab(tabfile):
    return map(lambda l:collapse_ws(l).split(' '),
            [l.strip().replace('\t','    ') for l in open(tabfile).readlines() if
            l.strip() and not l.strip().startswith('#')])

def readtab_attr(tabfile, attr):
    mtab_lines_fields = readtab(tabfile)
    mtab_lines_attr = []
    for line_fields in mtab_lines_fields:
        fieldmap = dict(zip(attr.split(' '), line_fields))
        mtab_lines_attr.append(confparse.Values(fieldmap))
    return mtab_lines_attr

"""
Parse file and return list of ojects with attribute access.
"""
readtab_attr_presets = dict(
  mtab=( '/etc/mtab', "device mount fstype mntattr dump fsck" ),
  mounts=( '/proc/mounts', "device mount fstype mntattr dump fsck" ),
  partitions=( '/proc/partitions', "major minor blocks device_node" )
)

def mtab_ignored(line, ctx):

    if ctx.filters.exclude_mount and line.mount in ctx.filters.ignores:
        return True

    if ctx.filters.devices and line.device not in ctx.filters.devices:
        return True

    if ctx.opts.flags.include_fstype:
        include_fstypes = ctx.opts.flags.include_fstype.split(' ')
        return line.fstype not in include_fstypes
    else:
        ignore_fstypes = ctx.opts.flags.ignore_fstype.split(' ')
        return line.fstype in ignore_fstypes



def H_disks(diskdata, ctx):

    """
    Lists locally mounted media. Normally this only includes mounts from a local device
    node.

    TODO: Iterate locally mounted media, get mount entry from catalog by device.
    Get media entry from catalog.
    Check catalog entries.
    """

    ctx.sources.partitions = readtab_attr(*readtab_attr_presets['partitions'])

    if not ctx.flags.include_devices and not ctx.flags.exclude_devices:
       ctx.flags.include_devices = [ "/dev/%s" % l.device_node for l in ctx.sources.partitions ]
    if not ctx.flags.include_types and not ctx.flags.exclude_types:
    	opts.flags.exclude_types = ['/var/lib/docker/aufs']

    ctx.sources.mtab = readtab_attr(*readtab_attr_presets['mtab'])

    for line in ctx.sources.mtab:
        if mtab_ignored( line, ctx ):
            continue
        print line.mount, line.device, line.fstype


def H_list_disks(diskdata, ctx):

    """
    XXX: iterate document mounts and media entries and print wether mounted or
    available at localhost.
    """

    mounts = subprocess.check_output('mount')
    #print 'Mounts', mounts

    devices = subprocess.check_output('find /dev/disk/by-uuid -type l'.split(' '))
    #print 'Devices', devices

    for id, attr in diskdata['catalog']['media'].items():
        print 'Disk', id
        # TODO: print when mounted
        for part in attr['partitions']:
            size = part['size']

            if 'UUID' not in part:
                print '  Incomplete data for', size
                continue
            if part['UUID'] not in devices:
                continue
            device = subprocess.check_output(['realpath',
                '/dev/disk/by-uuid/'+part['UUID']]).strip()
            device = subprocess.check_output(['realpath', device]).strip()

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
    ctx.opts = libcmd_docopt.get_opts(ctx.usage, argv=argv)

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
        diskdoc = os.path.expanduser(ctx.opts.flags.file)
        diskdata = yaml_load(open(diskdoc))
        func = ctx.opts.cmds[0]
        assert func in handlers
        return handlers[func](diskdata, ctx)


if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__doc__)
    ctx = confparse.Values(dict(
        usage=__doc__,
        out=sys.stdout,
        err=sys.stderr,
        inp=sys.stdin,
        opts=opts,
        sources=confparse.Values(),
        filters=confparse.Values(dict(
          devices=[],
          includes=[],
          ignores=[]
        ))
    ))
    sys.exit( main( ctx ) )
