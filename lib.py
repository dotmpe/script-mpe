import datetime
import getpass
import optparse
import os
import re
import socket
import subprocess
import sys

from os.path import basename, join,\
        isdir


#import confparse
#
#
#config = confparse.expand_config_path('cllct.rc')
#"Configuration filename."
#
#settings = confparse.load_path(*config)
#"Static, persisted settings."
    
hostname = socket.gethostname()
username = getpass.getuser()

# Util functions

rcs_path = re.compile('^.*\/\.(svn|git|bzr)$')

def is_versioned(dirpath):
    assert isdir(dirpath), dirpath
    for d in os.listdir(dirpath):
        p = join(dirpath, d)
        m = rcs_path.match(p)
        if m:
            return True

def cmd(cmd, *args):
    stdin,stdout,stderr = os.popen3(cmd % args)
    #TODO:stdin,stdout,stderr = subprocess.popen3('file -s %s' % p)
    stdin.close()
    errors = stderr.read()
    if errors:
        err(errors)
    return stdout.read()

def get_sha1sum_sub(path):
    """
    Utitilize OS sha1sum command which is likely more efficient than
    reading in the file in case of large files.

    Returns the hex formatted digest directly.
    """
    data = cmd("sha1sum %r", path)
    p = data.index(' ')
    hex_checksum, filename = data[:p], data[p:].strip()
    # XXX: sanity check..
    assert filename == path, (filename, path)
    return hex_checksum

def get_md5sum_sub(path):
    """
    Utitilize OS md5sum command which is likely more efficient than
    reading in the file in case of large files.

    Returns the hex formatted digest directly.
    """
    data = cmd("md5sum %r", path)
    p = data.index(' ')
    hex_checksum, filename = data[:p], data[p:].strip()
    # XXX: sanity check..
    assert filename == path, (filename, path)
    return hex_checksum

def remote_proc(host, cmd):
    proc = subprocess.Popen(
        'ssh '+ username+'@'+host + " '%s'" % cmd,
            shell=True,
            stderr=subprocess.PIPE, stdout=subprocess.PIPE,
            close_fds=True
        )
    errresp = proc.stderr.read()
    if errresp:
        errresp = "Error: "+ errresp.replace('ssh: ', host).strip()
        raise Exception(errresp)
    else:
        return proc.stdout.read().strip()

def human_readable_bytesize(length):
    if length > 1024**4:
        return "%sG" % (float(length)/1024**4)
    elif length > 1024**3:
        return "%sG" % (float(length)/1024**3)
    elif length > 1024**2:
        return "%sM" % (float(length)/1024**2)
    elif length > 1024:
        return "%sk" % (float(length)/1024)
    else:
        return "%s" % length

def tree_paths(path):

    """
    Yield all paths traversing from path to root.
    """

    parts = path.strip(os.sep).split(os.sep)
    while parts:
        cpath = join(*parts)
        if path.startswith(os.sep):
            cpath = os.sep+cpath
        
        yield cpath
        parts.pop()
        #parts = parts[:-1]


# The epoch used in the datetime API.
EPOCH = datetime.datetime.utcfromtimestamp(0)


def timedelta_to_seconds(delta):
    seconds = (delta.microseconds * 1e6) + delta.seconds + (delta.days * 86400)
    seconds = abs(seconds)

    return seconds

def datetime_to_timestamp(date, epoch=EPOCH):
    # Ensure we deal with `datetime`s.
    #date = datetime.datetime.utcfromtimestamp(date)
    epoch = datetime.datetime.utcfromtimestamp(epoch.toordinal())

    timedelta = date - epoch
    timestamp = timedelta_to_seconds(timedelta)

    return timestamp

def timestamp_to_datetime(timestamp, epoch=EPOCH):
    # Ensure we deal with a `datetime`.
    epoch = datetime.datetime.utcfromtimestamp(epoch.toordinal())

    epoch_difference = timedelta_to_seconds(epoch - EPOCH)
    adjusted_timestamp = timestamp - epoch_difference

    date = datetime.datetime.utcfromtimestamp(adjusted_timestamp)

    return date


if __name__ == '__main__':
    print get_sha1sum_sub("volume.py");

    for f in sys.argv:
        if not os.path.exists(f):
            continue
        for n, ts in (
                ('c',os.path.getctime(f)),
                ('a',os.path.getatime(f)),
                ('m',os.path.getmtime(f)),):
            print n, timestamp_to_datetime(ts), f

