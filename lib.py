import datetime
import getpass
import optparse
import os
import re
import socket
import subprocess
import sys

#import confparse
#
#
#config = confparse.get_config('cllct.rc')
#"Configuration filename."
#
#settings = confparse.yaml(*config)
#"Static, persisted settings."
    
hostname = socket.gethostname()
username = getpass.getuser()

# Util functions

rcs_path = re.compile('^.*\/\.(svn|git|bzr)$')

def is_versioned(dirpath):
    assert os.path.isdir(dirpath), dirpath
    for d in os.listdir(dirpath):
        p = os.path.join(dirpath, d)
        m = rcs_path.match(p)
        if m:
            return True


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
    for f in sys.argv:
        if not os.path.exists(f):
            continue
        for n, ts in (
                ('c',os.path.getctime(f)),
                ('a',os.path.getatime(f)),
                ('m',os.path.getmtime(f)),):
            print n, timestamp_to_datetime(ts), f

