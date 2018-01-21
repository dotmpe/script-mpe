#!/usr/bin/env python
"""
:Created: 2016-02-22

Python helper to query/update disk metadatadocument 'disks.yaml'

"""
from __future__ import print_function
__description__ = "diskdoc - Python helper to query/update disk metadatadocument 'disks.yaml'"
__version__ = '0.0.4-dev' # script-mpe
__couch__ = 'http://localhost:5984/the-registry'
__usage__ = """

Usage:
    diskdoc.py [options] disks
    diskdoc.py [options] list-disks
    diskdoc.py [options] dump-doc
    diskdoc.py [options] generate-doc
    diskdoc.py [options] readtab ID
    diskdoc.py [options] readout ID
    diskdoc.py [options] couchdb (stats|list)
    diskdoc.py --background
    diskdoc.py -h|--help
    diskdoc.py --version

Commands:
  disks
      Show local disks.
  list-disks
      ..
  dump-doc
      ..
  generate-doc
      ..
  (readtab|readout) ID
      Parse configurations for file or command output, dumps
      named fields/values for each line. For debugging.

Options:
  --couch=REF
                Couch DB URL [default: %s]
  --address ADDRESS
                The address that the socket server will be listening on. If
                the socket exists, any command invocation is relayed to the
                server intance, and the result output and return code
                returned to client. [default: /var/run/disk-doc-serv.sock]
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
  -q, --quiet   Turn off verbosity.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).

""" % ( __couch__, __version__, )
import sys
import os
import re
from fnmatch import fnmatch
from pprint import pprint, pformat
import subprocess
from UserList import UserList

from docopt import docopt
import uuid
from deep_eq import deep_eq

from script_mpe.libhtd import *
#from script_mpe import libcmd_docopt, confparse, taxus
#from script_mpe.res import js, Diskdoc, Homedir
#from script_mpe.confparse import yaml_load, yaml_safe_dumps
#from taxus import Taxus, v0



cmd_default_settings = dict(
        verbose=1,
        no_db=True,
    )


def yaml_commit(diskdata, ctx):
    yaml_safe_dumps(diskdata, open(ctx.opts.flags.file, 'w+'), default_flow_style=False)


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
        js.dumps(it.todict())

def H_readout(diskdoc, ctx):
    data = readout_attr( *readout_attr_presets[ctx.opts.args.ID] )
    for it in data:
        js.dumps(it.todict())


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
    Query host OS for disk info, print known entries from diskdoc. Matches are
    made based on volume UUID. Warning lines are emitted for local disks not
    documented, and document entries without UUID.

    NOTE the UUID is not the same as the partition UUID.
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

            UUID = None
            if 'UUID' in part:
                UUID = part['UUID']
            # TODO elif 'Disk-Partition-UUID' in part:
            #    UUID = part['Disk-Partition-UUID']

            if not UUID:
                print('  Incomplete data (missing partition uuid) for', descr)
                continue

            # Continue with local partitions only
            if UUID not in part_uuids:
                continue

            lpart = host_parts[part['UUID']]
            lpart.description = descr

            if disk_id not in local_:
                local_[disk_id] = disk

            local_parts[part['UUID']] = lpart

    for uuid in part_uuids:
        if uuid not in local_parts:
            print('  Undocumented disk', uuid, host_parts[uuid].todict())

    for disk_id, disk in local_.items():

        for part in disk['partitions']:
            UUID = None
            if 'UUID' in part:
                UUID = part['UUID']
            if not UUID or UUID not in local_parts: continue
            lpart = local_parts[UUID]
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

def H_check(ctx):

    """
    TODO: Regenerate status

    - available and used space per partition.
    - correct disk capacity
    - age in days, smart info
    - fstype, inode table usage
    - disk location, portable bit
    """

def H_status(ctx):

    """
    TODO: enumerate volmes. Display storage size, usage, fstype.
    """


def H_couchdb_sync(diskdata, ctx):
    "Copy / integrate document with CouchDB, TODO: see generate doc?"


def H_dump_doc(diskdata, ctx):
    """
    Dump entire document, media and also mounts and other metadata.
    Output format: JSON.
    """
    print( js.dumps(diskdata) )


def H_generate_doc(diskdata, ctx):
    """
    Dump media records for requested or local disks.
    TODO: same as lists-disks, generate/update cache storage document here
    """

    print( js.dumps(diskdata.local_doc()) )


### Transform H_ function names to nested dict

# XXX: testing libcmd_docopt get_cmd_handlers
commands = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    commands[k[2:].replace('_', '-')] = h
#commands = libcmd_docopt.get_cmd_handlers(globals(), 'H_')
#commands['help'] = libcmd_docopt.cmd_help


### Service global(s) and setup/teardown handlers

# XXX: no sessions
diskdata = None
def prerun(ctx, cmdline):
    global diskdata

    argv = cmdline.split(' ')
    ctx.opts = libcmd_docopt.get_opts(ctx.usage, argv=argv)

    if not diskdata:
        diskdata = Diskdoc.from_user_path(ctx.opts.flags.file)

    opts.diskdata = diskdata

    return []


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    opts.flags.update(dict(
        verbose = opts.flags.quiet and opts.flags.verbose or 1
    ))
    return init

def main(ctx):

    """
    Run command, or start socket server.
    """
    global commands

    ws = Homedir.require()
    #ws.yamldoc('disksync', defaults=dict(
    #        last_sync=None
    #    ))
    ctx.ws = ws
    ctx.settings = settings = opts.flags
    ctx.init()

    # Start background if requested, or pass command
    if ctx.settings.background:
        localbg = __import__('local-bg')
        return localbg.serve(ctx, commands, prerun=prerun)
    elif os.path.exists(ctx.settings.address):
        localbg = __import__('local-bg')
        return localbg.query(ctx)
    elif opts.cmds and 'exit' == opts.cmds[0]:
        print("No background process at %s" % ctx.settings.address, file=ctx.err)
        return 1
    else:

        # Normal run
        settings = settings
        settings.diskdata = Diskdoc.from_user_path(ctx.settings.file)

        settings.ctx = ctx
        return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'diskdoc/%s' % __version__



if __name__ == '__main__':
    usage = libcmd_docopt.static_vars_from_env(__usage__,
        ( 'COUCH_DB', __couch__ ) )
    opts = libcmd_docopt.get_opts(__description__ + usage,
            version=get_version(), defaults=defaults)
    # TODO: test local-bg after adding new context class
    ctx = Taxus()
    ctx.settings.update(dict(
        usage=__description__ + usage,
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
