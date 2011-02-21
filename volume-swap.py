#!/usr/bin/env python
"""rsr swap - detect status physical volumes

Paths
    - The global locator for the volume
    - The configured root for in-system volume references.
    - The configured root for duplicate volumes.

"""
import os, sys

import confparse


config = confparse.get_config('cllct.rc')
"Find configuration file. "

settings = confparse.yaml(*config)
"Parse settings. "



if __name__ == '__main__':
    volume_root = settings.rsr.volume_root.path
    dupe_root = settings.rsr.dupe_root.path
    for nr, volume_id in enumerate(settings.stores):

        volume = None
        if volume_id in settings.volume:
            volume = getattr(settings.volume, str(volume_id))
        if not volume:
            print >> sys.stderr, "Missing volume %s" % volume_id
            continue

        system_ref = volume.location
        path_ref = os.path.expanduser(
                os.path.join(volume_root, str(nr+1)))

        if not (os.path.exists(path_ref) or os.path.islink(path_ref)):
            print >>sys.stderr, "Missing or wrong type %s" % path_ref
            continue

        if not os.path.exists(os.path.realpath(path_ref)):
            print >>sys.stderr, "Broken %s" % path_ref
            continue

        print volume_id, path_ref

# realpath settings.rsr.volume_root volume_id 
# points to mount or local, real locator


