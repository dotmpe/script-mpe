#!/usr/bin/env python
"""map - rsync wrapper

Overview
--------
Besides an RCS, rsync is *the* tool to keep identical directories at separate
locations in sync. Especially when one deals with media files, this little gem
is the preferred tool over a full delta version system.

To automate the task, this scripts provides a few commands that make
rsync'ing several copies of a tree more akin to working with revision control.

TODO: Besides multiple synchronized working copies, it is possible to make backups
and to assist in merges of diverged working trees.


Implementation
--------------
To synchronize sides, there needs to be a common point of reference,
and delta's with this common denominator--one for each side.

To this end, every synchronisation is logged, specifically the timestamp of its
initiation. Then this script will take note of paths in the current subtree that
have been modified since that log file was last updated.

The mtime of the log file will correspond to the last line in the log.

If there is a non-zero delta at both sides, then user intervention is needed to
resolve changes made on both sides. This situation is sub-optimal. Rather, this
should be prevented by running the sync after making changes to the directory,
and/or just before starting modiciations.

With only one side 'out of sync', rsync can be ran with the ``-a --delete``
options.
This will greatly reduce accidental duplication of moved content, and allow
updates of timestamps without regard which side is most recent.

Using this out of sync detection, this script can propagate changes found on any
side, local or remote. The configuration accepts more than two sides and can
keep several host/directory paths in sync.
The restriction is that only one host may run out of sync at any time.
Also, all hosts need to be online during synchronisation otherwise merges might
be needed later.

Because of this detection keeping multiple copies of a working tree becomes more
secure and convenient.

XXX: Merge not simply means selecting the most recent file ofcourse.


TODO: By default, no revision h directory is included in the sync.

Options
-------

"""

import datetime
import getpass
import optparse
import os
import pprint
import re
import socket
import subprocess
import sys
from lib import is_versioned, remote_proc, datetime_to_timestamp, timestamp_to_datetime

import confparse


config = confparse.expand_config_path('cllct.rc')
"Configuration filename."

settings = confparse.load_path(*config)
"Static, persisted settings."

hostname = socket.gethostname()
username = getpass.getuser()

mapsync_file = settings.mapsync.log_file



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
    if mtimes:
        return mtimes[-1]
    else:
        return 0

def mapsync_delta(path):
    """
    Determine last mapsync update of the local directory,
    and the last update of the subtree.
    """
    mapsync_timestamp = None
    assert os.path.isdir(path), path
    mapsync_log = os.path.join(path, settings.mapsync.log_file)
    if os.path.exists(mapsync_log):
        stat = os.stat(mapsync_log)
        #assert stat.st_mtime >= stat.st_ctime
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
    p = os.path.join(rc, 'remote', map_id, host)
    if not os.path.isdir(p):
        os.makedirs(p)

    remote_src = "%s:%s" % (host, os.path.join(remotepath,
        settings.mapsync.log_file))
    local_target = os.path.join(rc, 'remote', host, map_id)

    mapsync_timestamp = None
    try:
        remote_copy(remote_src, local_target)
    except e:
        # Only allow missing path response:
        if "No such file or directory" in e.args[0]:
            err("mapsync: not initialized: %s:%s", host, remotepath)
            mapsync_timestamp = 0
        else:
            raise e
    assert os.path.exists(local_target)
    mapsync_timestamp = os.path.getmtime(local_target)
    assert open(local_target).readlines()[-1].strip() == str(mapsync_timestamp)
    #
    worktree_timestamp, last_remote_path = remote_proc(host,
        "~/project/script-mpe/findlatest.py --print-timestamp %s/" % remotepath).split(' ')
    worktree_timestamp = float(worktree_timestamp)
    #
    return mapsync_timestamp, worktree_timestamp

def rsync(*flags):
    args = ['rsync'] + list(flags)
    proc = subprocess.Popen(
            args,
            stderr=subprocess.PIPE, stdout=subprocess.PIPE,
            close_fds=True
        )
    errresp = proc.stderr.read()
    if errresp:
        errresp = "Error: "+ errresp.strip()
        raise Exception(errresp)
    info('rsync %s', " ".join(args) )
    print proc.stdout.read()
    info('rsync done')

def remote_copy(src, trgt):
    args = ['scp', '-pq', src, trgt]
    proc = subprocess.Popen(
            args,
            stderr=subprocess.PIPE, stdout=subprocess.PIPE,
            close_fds=True
        )
    errresp = proc.stderr.read()
    if errresp:
        errresp = "Error: "+ errresp.replace('scp: ', host).strip()
        raise Exception(errresp)
    info(" ".join(args))
    print proc.stdout.read()
    info('scp -pq done')

class Map:
    def __init__(self, map_id, host, path, mapsync):
        self.map_id = map_id
        self.path = path
        self.host = host
        self.worktree_stamp = None
        self.mapsync_stamp = None
        self.container = mapsync

    def fetch_stamps(self):
        if self.islocal:
            self.mapsync_stamp, self.worktree_stamp =\
                    mapsync_delta(self.path)
        else:
            self.mapsync_stamp, self.worktree_stamp =\
                    remote_mapsync_delta(self.map_id, self.host, self.path)

    def update_log(self, timestamp):
        """
        Update log at current side.
        """
        global settings, hostname
        if isinstance(timestamp, float):
            timestamp = int(round(timestamp))
        assert isinstance(timestamp, int), type(timestamp)
        log_file = None
        if self.islocal:
            log_file = os.path.join(self.path, settings.mapsync.log_file)
            open(log_file, 'w').write("%s\n" % timestamp)
            os.utime(log_file, (timestamp, timestamp))
        else:
            rc = os.path.expanduser(os.path.join('~', '.mapsync'))
            log_file = os.path.join(rc, 'remote', self.map_id, host, settings.mapsync.log_file)
            assert os.path.exists(log_file), log_file
            open(log_file, 'w').write("%s\n" % timestamp)
            os.utime(log_file, (timestamp, timestamp))
            remote_copy(log_file, str(self)+os.sep+settings.mapsync.log_file)

    @property
    def islocal(self):
        global hostname
        return self.host == hostname

    @property
    def initialized(self):
        return self.mapsync_stamp and self.mapsync_stamp > 0

    @property
    def isempty(self):
        return not self.worktree_stamp

    @property
    def insync(self):
        return self.mapsync_stamp >= self.worktree_stamp

    @property
    def ismodified(self):
        return self.worktree_stamp and self.worktree_stamp > 0

    def human_readable_delta(self):
        if not self.insync:
            return human_readable_timedelta(self.worktree_stamp - self.mapsync_stamp)
        elif self.worktree_stamp < self.mapsync_stamp:
            pass
        return 0.0

    def __str__(self):
        global hostname
        if self.host != hostname:
            return "%s:%s" % (self.host, self.path)
        else:
            return self.path


class MapSync:
    def __init__(self, map_id):
        self.map_id = map_id
        self.paths = {}
        self.hosts = {}
        self.maps = []
    def add(self, host, path, fetch_stamps=True):
        side = Map(self.map_id, host, path, self)
        if fetch_stamps:
            side.fetch_stamps()
        if path not in self.paths:
            self.paths[path] = []
        self.paths[path].append(side)
        if host not in self.hosts:
            self.hosts[host] = []
        self.hosts[host].append(side)
        self.maps.append(side)
        return side
    def find_optimum_source(self, otherside):
        side = None
        # try to find a second local path
        for local in self.maps:
            if local.host != otherside.host or not local.insync:
                continue
            if local.path != otherside.path:
                side = local
                break
            # XXX: further optimization through detecting physical disks..
        if not side:
            for any in self.maps:
                if not any.insync:
                    continue
                if any.path != otherside.path or any.host != otherside.host:
                    side = any
                    break
        return side

def human_readable_timedelta(td):
    if td > 60*60*24:
        return "%sd" % (float(td)/24/60/60)
    elif td > 60*60:
        return "%sh" % (float(td)/60/60)
    elif td > 60:
        return "%sm" % (float(td)/60)
    else:
        return "%ss" % td

def sync(map_id, do_sync=True):

    """
    Synchronize changes from one location and or add several new empty locations.

    At least one location must be initialized. Changes on several locations will
    need to be resolved manually first.
    """

    global settings, hostname

    #if settings.verbose:
    info("mapsync: map '%s' (%i locations)", map_id, len(settings.map[map_id]))

    mapsync = MapSync(map_id)

    out_of_sync = []
    # locations with modifications since last sync
    #local_paths = []
    # locations on the current host
    new_paths = []
    # locations without mapsync log

    # Populate lists
    for location in settings.map[map_id]:
        if do_sync:
            info("mapsync: scanning %s at %s (%s)", map_id, location.host, location.path)
        map = mapsync.add(location.host, location.path, fetch_stamps=do_sync)
        if not do_sync:
            continue
        if map.insync:
            info("location %s:%s up to date", location.host, location.path)
        elif map.initialized:
            info("location %s:%s out of sync with %s", location.host,
                    location.path, map.human_readable_delta())
            out_of_sync.append(map)
        else:
            if map.ismodified:
                err("location %s:%s not empty, ignored", location.host, location.path)
                continue
            else:
                info("new location at %s:%s", location.host, location.path)
            new_paths.append(map)

    if not do_sync:
        return mapsync

    synctime = datetime.datetime.now()
    synctimestamp = float(synctime.strftime('%s'))
    #info("sync time %s", datetime.datetime.utcfromtimestamp(synctimestamp))
    info("sync time %s", datetime.datetime.fromtimestamp(synctimestamp))
    info("sync time %s", synctimestamp)

    # Synchronize if needed/possible
    sync_from = None
    if not out_of_sync:
        if not new_paths:
            print "mapsync: nothing to sync"
            return
    elif len(out_of_sync) > 1:
        print "mapsync: multiple sides out of sync"
        raise Exception("n-way merge not supported")
    else:
        sync_from = out_of_sync[0]

    if sync_from:
        info('updating logs to %s', synctime)
        sync_from.update_log(synctimestamp)

        for map in mapsync.maps:
            if map.path == sync_from.path or map.host == sync_from.host:
                continue
            if not map.insync:
                assert not map.initialized
                #fatal("cannot sync %s:%s, no up-to-date copy", to_sync.host,
                #        to_sync.path)
                continue
            #mapsync.synchronize(sync_from, map)
            info('sync %s to %s', sync_from, map)
            rsync('-avzi', '--delete', '%s/' % sync_from,
                    '%s:%s' % map)
    else:
        info('updating logs to %s', synctime)
        for map in mapsync.maps:
            if not map.insync:
                continue
            map.update_log(synctimestamp)

    # Initialize new locations
    for map in new_paths:
        sync_from = mapsync.find_optimum_source(map)
        if not sync_from:
            fatal("cannot sync %s:%s, no up-to-date copy",
                    map.host, map.path)
        assert sync_from, map
        info('new copy: %s', map)
        rsync('-avzi', '--delete', '%s/' % sync_from, str(map))
        info("ready: copy: %s", map)

    return

def init(map_id):

    """
    Initialize one or more locations.

    If no locations have been initialized yet and there are working trees
    present at one or more loctions these will be merged. Newest files
    will be added (ie. rsync -u).

    If this map was initialized before new locations can only be added if empty.
    Otherwise manual merge into one of the other locations is required first.
    """

    global settings, hostname

    #if settings.verbose:
    info("mapsync: init '%s' (%i locations)", map_id, len(settings.map[map_id]))

    mapsync = MapSync(map_id)

    out_of_sync = []
    new_paths = []
    worktree_paths = []

    # Populate lists
    for location in settings.map[map_id]:
        info("mapsync: scanning %s at %s (%s)", map_id, location.host, location.path)
        map = mapsync.add(location.host, location.path)
        if map.insync:
            info("location %s:%s up to date", location.host, location.path)
        elif map.initialized:
            info("location %s:%s out of sync with %s", location.host,
                    location.path, map.human_readable_delta())
            out_of_sync.append(map)
        else:
            if map.ismodified:
                info("existing contents at %s:%s", location.host, location.path)
                worktree_paths.append(map)
            else:
                info("new location at %s:%s", location.host, location.path)
            new_paths.append(map)

    fatal('todo: init')

# util

def info(v, *args):
    msg = "mapsync: %s" % v
    if args:
        msg = msg % args
    print msg

def err(v, *args):
    msg = "mapsync: error: %s" % v
    if args:
        msg = msg % args
    print >> sys.stderr, msg

def fatal(v, *args):
    err(v, *args)
    sys.exit(1)


usage_descr = """%prog [options] [path-or-map-id]"""

options_spec = (
    (('--init',), {'action': 'store_true', 'help':
        " " }),
    (('--list-maps',), {'action': 'store_true', 'help':
        " " }),
    (('--sync-log',), {'default': mapsync_file, 'help':
        "The file to which the synchronisation timestamps are written. "
        "Just the last line is needed, in case this log becomes to large. " }),
)


exclusive_options = ('init', 'list-maps')

def assert_exclusive_opt(option, values):
    excl_opts = list(exclusive_options)
    excl_opts.remove(option)
    for opt in excl_opts:
        opt = opt.replace('-', '_')
        if getattr(values, opt) == True:
            fatal("--%s cannot be used with --%s", opt, option)

def main(argv=[]):
    global settings

    info("on host '%s'", hostname)

    prsr = optparse.OptionParser(usage=usage_descr)
    for a,k in options_spec:
        prsr.add_option(*a, **k)
    opts, args = prsr.parse_args(sys.argv)

    args = args[1:]
    pwd = os.getcwd()
    if not args:
        args = [pwd]

    for map_id in args:
        assert map_id in settings.map, "Unknown map %s" % map_id
        if opts.list_maps:
            assert_exclusive_opt('list-maps', opts)
            mapsync = sync(map_id, do_sync=False)
            for i, map in enumerate(mapsync.maps):
                info("%s %s: %s:%s", map_id, i, map.host, map.path)
        elif opts.init:
            assert_exclusive_opt('init', opts)
            init(map_id)
        else:
            # default action
            sync(map_id)


if __name__ == '__main__':
    reload()
    main()
#    settings.commit()


