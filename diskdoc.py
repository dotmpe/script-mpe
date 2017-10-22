#!/usr/bin/env python
"""
:created: 2016-02-22

Python helper to query/update disk metadatadocument 'disks.yaml'

Usage:
    diskdoc.py [options] disks
    diskdoc.py [options] list-disks
    diskdoc.py [options] dump-doc
    diskdoc.py [options] generate-doc
    diskdoc.py [options] readtab ID
    diskdoc.py [options] readout ID

Commands:
    disks
        Show local disks.
    list-disks
        ..
    generate-doc
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
                Give custom path to projectdir document file
                [default: ~/.conf/disk/mpe.yaml]
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
from __future__ import print_function
import sys, socket
import os
import re
from fnmatch import fnmatch
from pprint import pprint, pformat
import subprocess
from UserList import UserList

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

def readtab(tabdata):
    return map(lambda l:collapse_ws(l).split(' '), [
        l.strip().replace('\t','    ') for l in tabdata if
            l.strip() and not l.strip().startswith('#') ] )

def handle_tab_lines(tab_lines_fields, attr):
    tab_lines_attr = []
    for line_fields in tab_lines_fields:
        fieldmap = dict(zip(attr.split(' '), line_fields))
        tab_lines_attr.append(confparse.Values(fieldmap))
    return tab_lines_attr

def readtab_attr(tabfile, attr):
    tab_lines_fields = readtab(open(tabfile).readlines())
    return handle_tab_lines( tab_lines_fields, attr )

def readout_attr(cmd, attr):
    out = subprocess.check_output(cmd).strip().split('\n')
    return handle_tab_lines( readtab( out ), attr )

"""
Parse file and return list of ojects with attribute access.
"""
readtab_attr_presets = dict(
  mtab=( '/etc/mtab', "device mount fstype mntattr dump fsck" ),
  mounts=( '/proc/mounts', "device mount fstype mntattr dump fsck" ),
  partitions=( '/proc/partitions', "major minor blocks device_node" )
)


readout_attr_presets = dict(
  darwin_lib_mounts=( ['darwin.lib.sh','darwin_mounts'], "mount device vol_uuid fstype_descr" ),
  linux_mounts=( ['mount'], "device _ mount _ type opts" ),
  linux_df=( ['bash', '-c', 'df | sed 1d'], "filesystem _1kblocks used available usePct mount" ),
  linux_df_local=( ['bash', '-c', 'df -l | sed 1d'], "filesystem _1kblocks used available usePct mount" ),

  # NOTE: need to query OS for block size; 1k or 512b
  df_posix=( ['bash', '-c', 'df -P | sed 1d'], "filesystem blocks used available usePct mount" ),

  #darwin_mount_stats=( '/proc/partitions', "" )

  # Map device,uuid for all local storage devices
  udev_uuid_links=( ['bash', '-c',
      'find /dev/disk/by-uuid -type l |'
      ' while read p; do echo "$(basename "$p") $(realpath $p)"; done'
    ], "uuid device" )
)

def H_readtab(diskdoc, ctx):
    data = readtab_attr( *readtab_attr_presets[ctx.opts.args.ID] )
    for it in data:
        print(it.todict())

def H_readout(diskdoc, ctx):
    data = readout_attr( *readout_attr_presets[ctx.opts.args.ID] )
    for it in data:
        print(it.todict())


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


def map_udev_uuids(forward=True, reverse=False):
    devices = UserList(readout_attr(*readout_attr_presets['udev_uuid_links']))

    if forward:
        devices.to_uuid = dict(zip( [ p.device for p in devices ], [
                p.uuid for p in devices ] ))
    if reverse:
        devices.to_dev = dict(zip( [ p.uuid for p in devices ], [
                p.device for p in devices ] ))

    return devices


def fetch_parts_attr(parts, ctx, *attr):
    "Helper to fetch additional attributes for .. partition "

    if not parts:
        return parts

    for a in attr:
        if not ( a in parts[0] and parts[0][a] ):
            if a == 'device':
                parts.uuids = map_udev_uuids()
            elif a == 'vol_uuid':
                parts.uuids = map_udev_uuids()

    for it in parts:
        for a in attr:
            if not ( a in it and it[a]):
                #if a == 'device':
                #    it[a] = parts.uuids.to_dev[it['vol_uuid']]
                if a == 'vol_uuid':
                    it[a] = parts.uuids.to_uuid[it['device']]
                else:
                    raise Exception("Cant resolve {0} for partition".format(a))

    return parts


def get_local_parts(ctx, *attr):
    "Get a list of available/mounted local partitions"
    parts = UserList()

    # Get a list of objects depending on host OS
    if ctx.uname == 'Darwin':
        parts.extend( readout_attr(*readout_attr_presets['darwin_lib_mounts']) )

    elif ctx.uname == 'Linux':
        parts.extend( [ p for p in
                    readout_attr( *readout_attr_presets['linux_mounts'] )
                if os.path.exists(p.device) ] )

    else:
        raise Exception("Unknown OS '{0}'".format(ctx.uname))

    # Fill in missing attributes, if requested explicitly
    return fetch_parts_attr(parts, ctx, *attr)


def H_disks(diskdata, ctx):

    """
    Lists locally mounted media. Normally this only includes mounts from a
    local device node.

    TODO: Iterate locally mounted media, get mount entry from catalog by device.
    Get media entry from catalog.
    Check catalog entries.
    """

    ctx.sources.partitions = readtab_attr(*readtab_attr_presets['partitions'])

    if not ctx.opts.flags.include_device and not ctx.opts.flags.exclude_device:
       ctx.opts.flags.include_device = [ "/dev/%s" % l.device_node for l in ctx.sources.partitions ]
    if not ctx.opts.flags.include_type and not ctx.opts.flags.exclude_type:
    	opts.flags.exclude_type = ['/var/lib/docker/aufs']

    ctx.sources.mtab = readtab_attr(*readtab_attr_presets['mtab'])

    for line in ctx.sources.mtab:
        if mtab_ignored( line, ctx ):
            continue
        print(line.mount, line.device, line.fstype)


def get_local_doc(diskdata, ctx):

    """
    Query host OS for disk info, the main bits we need is the UUID for the
    partition devices. Which in udev terms seems to be something different
    from the partuuid.

    And ofcourse we want at least the the device name or path and/or mount
    point as lookup too.
    """

    # Query OS for local partition info
    host_parts = dict([ (p.vol_uuid, p) for p in get_local_parts(ctx,
        'vol_uuid', 'device' ) ])
    part_uuids = host_parts.keys()

    # Go over disks, physical storage media items from catalog.
    # And build a list of local disks and partitions
    local_ = {}
    local_parts = {}
    for disk_id, disk in diskdata['catalog']['media'].items():

        for part in disk['partitions']:
            size = part['size']
            if 'description' in part and part['description']:
                descr = part['description']
            elif 'mount-prefix' in part:
                descr = part['mount-prefix']
            else:
                descr = size

            if 'UUID' not in part:
                print('  Incomplete data (missing partition uuid) for', descr)
                continue

            # Continue with local partitions only
            if part['UUID'] not in part_uuids:
                continue

            lpart = host_parts[part['UUID']]
            lpart.description = descr

            if disk_id not in local_:
                local_[disk_id] = disk

            local_parts[part['UUID']] = lpart


    for disk_id, disk in local_.items():

        for part in disk['partitions']:
            if 'UUID' not in part or part['UUID'] not in local_parts: continue
            lpart = local_parts[part['UUID']]
            size = part['size']

            if lpart.mount:
                assert os.path.exists(lpart.mount)
                vol_part_leaf = os.path.join(lpart.mount, '.volumes.sh')
                print('  Mounted:', size, lpart.device, lpart.description,
                        file=sys.stderr)
                if not os.path.exists(vol_part_leaf):
                    print('  Unknown:', size, lpart.device, lpart.description,
                            file=sys.stderr)
            else:
                print('  Available:', size, lpart.device, lpart.description,
                        file=sys.stderr)

    #yaml_commit(diskdata, ctx)


def H_list_disks(diskdata, ctx):

    """

    XXX: iterate document mounts and media entries and print wether mounted or
    available at localhost.
    """

    get_local_doc(diskdata, ctx)


def H_dump_doc(diskdata, ctx):
    """
    Dump entire document, media and also mounts and other metadata.
    """
    pprint(diskdata)


def H_generate_doc(diskdata, ctx):
    """
    Dump media records for requested or local disks.
    TODO: same as lists-disks, generate/update cache storage document here
    """


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

    Normally this returns after running a single subcommand. If backgrounded,
    there is at most one server per projectdir document. The server remains in
    the working directory, and while running is used to resolve any calls. Iow.
    subsequent executions turn into UNIX domain socket clients in a transparent
    way, and the user command invocation is relayed via line-based protocol to
    the background server isntance.

    For projectdir document, which currently is 15-20kb, this setup has a
    minimal performance boost, while the Pd does not need to be loaded from and
    committed back to disk on each execution.

    """

    if ctx.opts.flags.background:
        localbg = __import__('local-bg')
        return localbg.serve(ctx, handlers, prerun=prerun)
    elif os.path.exists(ctx.opts.flags.address):
        localbg = __import__('local-bg')
        return localbg.query(ctx)
    elif 'exit' == ctx.opts.cmds[0]:
        print("No background process at %s" % ctx.opts.flags.address, file=ctx.err)
        return 1
    else:
        diskdoc = os.path.expanduser(ctx.opts.flags.file)
        diskdata = yaml_load(open(diskdoc))
        func = ctx.opts.cmds[0]
        assert func in handlers
        return handlers[func](diskdata, ctx)


if __name__ == '__main__':
    opts = libcmd_docopt.get_opts(__doc__)
    ctx = confparse.Values(dict(
        uname=os.uname()[0],
        hostname=socket.gethostname(),
        usage=__doc__,
        out=sys.stdout,
        err=sys.stderr,
        inp=sys.stdin,
        opts=confparse.Values(opts),
        sources=confparse.Values(),
        filters=confparse.Values(dict(
          devices=[],
          includes=[],
          ignores=[]
        ))
    ))
    sys.exit( main( ctx ) )
