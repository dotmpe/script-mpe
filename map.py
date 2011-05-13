#!/usr/bin/env python
"""map - rsync wrapper

Overview
--------
Besides an RCS, rsync is the tool to keep identical directories at separate
locations in sync. Especially when one deals with media files, this little gem
is the preferred tool.

To synchronize both sides though, there needs to be a common point of reference,
and two delta's from this common denominator--one for each side.

To this end, every synchronisation is logged, specifically the timestamp of its
initiation. Then this script will take note of paths in the current subtree that
have been modified since that log file was last updated.

FIXME: It will then compare this delta to the remote side.

If there is a non-zero delta at both sides, then user intervention is needed to
resolve changes made on both sides. This situation is sub-optimal. Rather, this 
should be prevented by running the sync after making changes to the directory, 
and/or just before starting modiciations. 

With only one side 'out of sync', rsync can be ran with the ``--delete`` option.
This will greatly reduce accidental duplication of moved content.

Using this out of sync detection, this script can propagate changes found on any
side, local or remote. The configuration accepts more than two sides and can
keep several host/directory paths in sync.

Options
-------

"""

import os
import socket
import sys

import confparse


config = confparse.get_config('cllct.rc')
"Configuration filename."

settings = confparse.yaml(*config)
"Static, persisted settings."


def reload():
    global settings
    settings = settings.reload()
    if 'dynamic' not in settings:
        settings['dynamic'] = []
    # List all sync'ed map-id's for this host
    settings['sync'] = confparse.Values({}, root=settings)
    hostname = socket.gethostname()
    print hostname
    for map_id in settings.map:
        for side in settings.map[map_id]:
            if side.host != hostname:
                continue
            settings.sync[side.path] = map_id
    if 'sync' not in settings.dynamic:
        settings.dynamic.append('sync')

def main(argv=[]):
    global settings
    if not argv:
        argv = sys.argv[1:]
    reload()
    settings.commit()
    pwd = os.getcwd()

if __name__ == '__main__':
    main()

