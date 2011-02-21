#!/usr/bin/env python
"""rsr swap - detect status physical volumes

Paths
    - The global locator for the volume
    - The configured root for in-system volume references.
    - The configured root for duplicate volumes.

"""
import os, re, sys
from os.path import join, isdir

import confparse


config = confparse.get_config('cllct.rc')
"Find configuration file. "

settings = confparse.yaml(*config)
"Parse settings. "


system, debug, info, action, warning, error = range(0,6)
CHATTER = 1

def log(level, msg, *args):
    print >>sys.stderr, msg % args


BLKID_PROPS = re.compile('([A-Z]+)=\"([^\"]+)\"')

def disk_id(dev):
    # XXX: cannot get System ID for disk without root?
    lines = os.popen('sudo /lib/udev/ata_id %s' % dev).readlines()
    return lines[0].strip()

def partition_uuid(dev):

    lines = os.popen('/sbin/blkid').readlines()
    for line in lines:

        if not line.startswith(dev):
            continue

        p = line.find(':')
        dev, descr = line[:p].strip(), line[p+1:].strip()

        M = BLKID_PROPS.findall(descr)
        if M:
            props = dict(M)
            return props['UUID']

        log(error, "cannot find UUID %s, %s", dev, descr)

#print disk_id('/dev/hda')
#print partition_uuid('/dev/hda1')
#print partition_uuid('/dev/hda6')
#sys.exit()

def volume_meta(path, init=False):

    """
    Return parsed volume metadata (YAML), optionally initialize.
    """

    # Default volume metadata locations
    paths = [join(path,'.rsr'), join(path,'.'), path]

    # first pass
    rc = list(confparse.get_config('volume-meta', paths=paths))

    # initialize if missing
    if init and not rc:
        assert isdir(path), path
        default = join(path, '.volume-meta')
        rc = confparse.init_config('volume-meta', paths=paths, default=default)

    # return parsed but no error on missing volume meta 
    if rc:
        return confparse.yaml(*rc)


if __name__ == '__main__':

    volume_root = settings.rsr.volume_root.path
    dupe_root = settings.rsr.dupe_root.path
    for nr, volume_id in enumerate(settings.stores):

        volume = None
        if volume_id in settings.volume:
            volume = getattr(settings.volume, str(volume_id))
        if not volume:
            print >> sys.stderr, "Missing storage %s" % volume_id
            continue

        system_ref = volume.location
        path_ref = os.path.expanduser(
                os.path.join(volume_root, str(nr+1)))

        if not (os.path.exists(path_ref) or os.path.islink(path_ref)):
            print >>sys.stderr, "Missing storage or wrong type %s" % path_ref
            continue

        if not os.path.exists(os.path.realpath(path_ref)):
            log(error, "Broken link to storage %s", path_ref)
            continue

        # XXX: can we identify the mount point of this or a containing ref?
       # mount_ref = os.path.realpath(path_ref)
       # p = mount_ref.split(os.sep)
       # while p:
       #     if os.path.ismount(mount_ref):
       #         break

       #     p.pop()
       #     if p:
       #         mount_ref = os.path.realpath(os.sep.join(p))
       #     else:
       #         mount_ref = os.sep # xxx root
       # if mount_ref == os.sep:
       #     # is root, ie. local system
       #     mount_ref = None
       #
        # no, at the moment, use in-volume metadata
        meta = volume_meta(path_ref)

        # init?
        if not meta or ('UUID' not in meta and 'system-id' not in meta):
            if not meta:
                meta = confparse.Values()
            if 'UUID' not in volume:
                assert 'system-id' in volume, \
                        "missing both UU and System ID for %r" % volume
                meta['system-id'] = volume['system-id']
                
            meta.UUID = volume.UUID
        if meta.UUID != volume.UUID:
            log(error, "Volume UUID mismatch: %s (metadata) vs. %s (system)", 
                    meta.UUID, volume.UUID)
            continue
        
        print volume_id, path_ref, mount_ref


# realpath settings.rsr.volume_root volume_id 
# points to mount or local, real locator


