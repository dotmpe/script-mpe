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

The only downside versus an RCS is that only one host may run out of sync at any
time, and that all hosts need to be online for a successful synchronisation. 
One a host is offline during synchronisation it will also need to be updated by
hand.


Options
-------

"""

import optparse
import os
import re
import socket
import subprocess
import sys

import confparse


config = confparse.get_config('cllct.rc')
"Configuration filename."

settings = confparse.yaml(*config)
"Static, persisted settings."
    
hostname = socket.gethostname()
username = getpass.getuser()

mapsync_file = settings.mapsync.log_file

usage_descr = """%prog [options] [path-or-map-id]*"""

options_spec = (
    ('--sync-log', {'default': mapsync_file, 'help':
        "The file to which the synchronisation timestamps are written. "
        "Just the last line is needed, in case this log becomes to large. " }),
)



def reload():
    global settings, hostname
    settings = settings.reload()
    if 'dynamic' not in settings:
        settings['dynamic'] = []
    # List all sync'ed map-id's for this host
    settings['maps'] = confparse.Values({}, root=settings)
    for map_id in settings.map:
        for side in settings.map[map_id]:
            if side.host != hostname:
                continue
            settings.maps[side.path] = map_id
    if 'maps' not in settings.dynamic:
        settings.dynamic.append('maps')

rcs_path = re.compile('^.*\/\.(svn|git|bzr)$')

def is_versioned(dirpath):
    assert os.path.isdir(dirpath), dirpath
    for d in os.listdir(dirpath):
        p = os.path.join(dirpath, d)
        m = rcs_path.match(p)
        if m:
            if settings.verbose:
                print 'found rcs path', dirpath, d
            return True

def get_last_mtime(path, ignore_versioned=True):
    if ignore_versioned:
        if is_versioned(path):
            return
    mtimes = []
    for root, dirs, files in os.walk(path):
        if ignore_versioned:
            rmdirs = []
            for d in dirs:
                p = os.path.join(root, d)
                if is_versioned(p):
                    if settings.verbose:
                        print 'ignored', p
                    rmdirs.append(d)
            for d in rmdirs:
                dirs.remove(d)
        for f in files:
            p = os.path.join(root, f)
            if os.path.exists(p):
                mtimes.append(os.path.getmtime(p))
    mtimes.sort()
    return mtimes[-1]

def mapsync_delta(path):
    """
    Determine last mapsync update of the local directory,
    and the last update of the subtree.
    """
    mapsync_timestamp = None
    stat = os.stat(path)
    assert stat.st_mtime >= stat.st_ctime
    mapsync_timestamp = stat.st_mtime
    #
    worktree_timestamp = get_last_mtime(path)
    return mapsync_timestamp, worktree_timestamp

def remote_mapsync_delta(map_id, host, remotepath):
    """
    Determine last mapsync update of the remote directory,
    and the last update of the remote tree.
    """
    rc = os.path.expanduser(os.path.join('~', '.mapsync'))
    p = os.path.join(rc, 'remote', host)
    if not os.path.isdir(p):
        os.makedirs(p)

    src = "%s:%s" % (host, os.path.join(remotepath, '%s' %
        settings.mapsync.log_file))
    trgt = os.path.join(rc, 'remote', host, map_id)

    proc = subprocess.Popen(
            ['scp', '-pq', src, trgt], 
            stderr=subprocess.PIPE, stdout=subprocess.PIPE,
            close_fds=True
        )
    errresp = proc.stderr.read()
    if errresp:
        errresp = "Error: "+ errresp.replace('scp: ', host).strip()
        # Only allow missing path response:
        if "No such file or directory" not in errresp:
            raise Exception(errresp)
    else:
        print 'done', (proc.stdout.read(),)
        mapsync_timestamp = os.path.getmtime(trgt)
        assert open(trgt).readlines()[-1].strip() == str(mapsync_timestamp)
    #
    worktree_timestamp = None
    proc = subprocess.Popen(
            ['ssh', username+'@'+host, "'~/project/script.mpe/findlatest.py %s'" % path]
            stderr=subprocess.PIPE, stdout=subprocess.PIPE,
            close_fds=True
        )
    errresp = proc.stderr.read()
    if errresp:
        errresp = "Error: "+ errresp.replace('scp: ', host).strip()
        raise Exception(errresp)
    else:
        print 'done', (proc.stdout.read(),)
    #
    return mapsync_timestamp, worktree_timestamp

def human_readable_timedelta(td):
    if td > 60*60*24:
        return "%s days" % (float(td)/24/60/60)
    elif td > 60*60:
        return "%s hours" % (float(td)/60/60)
    elif td > 60:
        return "%s minutes" % (float(td)/60)
    return td

def sync(map_id):
    global settings, hostname

    #if settings.verbose:
    print "mapsync: synchronizing '%s'"% map_id, "(%i locations)" %\
            len(settings.map[map_id]), 'from', hostname

    for location in settings.map[map_id]:
        if location.host == hostname:
            print 'mapsync: Scanning %s' % location.path
            mapsync_timestamp, worktree_timestamp =\
                    mapsync_delta(location.path)
        else:
            print 'mapsync: Scanning %s:%s' % (location.host, location.path)
            mapsync_timestamp, worktree_timestamp =\
                    remote_mapsync_delta(map_id, location.host, location.path)
        if mapsync_timestamp != worktree_timestamp:
            if worktree_timestamp > mapsync_timestamp:
                print "mapsync: out of date at: `%s <%s:%s>" %(map_id, location.host, location.path)
                print "mapsync: %s:%s modified %s after last sync" % (
                        location.host, location.path, 
                        human_readable_timedelta( worktree_timestamp - mapsync_timestamp ))
    #return mapsync_timestamp

def main(argv=[]):
    global settings

    pwd = os.getcwd()
    if not argv:
        argv = sys.argv[1:]
    if not argv:
        argv = [pwd]

    mapsync_file = settings.mapsync.log_file

    for path in argv:
        log_file = os.path.join(os.path.join(path, mapsync_file))
        if not os.path.exists(log_file):
            log_file = confparse.find_parent(mapsync_file, path).next()
        map_id = settings.maps[os.path.dirname(log_file)]
        sync(map_id)
    

#    settings.commit()


if __name__ == '__main__':
    reload()
    main()

