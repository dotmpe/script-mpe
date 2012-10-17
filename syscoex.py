#!/usr/bin/env python
"""

System Complexity
=================



"""
import os
import confparse
import statvfs
import subprocess
import datetime
from pprint import pformat
try:
    import bencode
except:
    bencode = None
# use jsonlib or simplejson
try:
    import simplejson as _json
except:
    import json as _json

json_read = _json.loads
json_write = _json.dumps

storage = {
        'a8c01c01': confparse.Values(dict(
            name='dandy',
            fs=confparse.Values(dict(
                inodes=15196160
            ))
        )),
        'Pandora.local': confparse.Values(dict(
            name='Pandora',
            fs=confparse.Values(dict(
                inodes=48828123
            )),
        )),
        '007f0101': confparse.Values(dict(
            name='dm',
            fs=confparse.Values(dict(
                inodes=3538944
            ))
        ))
    }

def complexity( data ):
    max_inodes = 0
    for key, record in storage.items():
        if record.fs.inodes > max_inodes:
            max_inodes = record.fs.inodes
    print data.fs.inodes * 100 / max_inodes, 'percent'

def main( ):
    data = confparse.Values(dict(
            version=1
        ))
    print '='*79
    data.hostid = os.popen2( 'hostid' )[ 1 ].read().strip()
    data.date = datetime.datetime.now().isoformat()
    print 'Date:', data.date#.isoformat()
    print 'Host-ID:', data.hostid
    fssttat = os.statvfs( os.sep )
    print 'Filesystem:', os.sep
    print '_'*79
    data.fs = confparse.Values(dict(
        ))
    # finding total inode stats is more involved, block is more simple
#    print fssttat.f_bsize, "preferred blocksize"
#    print fssttat.f_frsize, "fundamental filesystem block"
#    print fssttat.f_blocks, 'blocks (total, in units of f_frsize)'
#    print fssttat.f_bfree, 'free blocks'
    data.fs.inodes = fssttat.f_files
    print 'INodes', data.fs.inodes
#    print fssttat.f_favail, 'inodes free' available to non-super user, same as ffree
    data.fs.inodes_used = fssttat.f_files - fssttat.f_ffree
    print 'INodes-Used:', data.fs.inodes_used
    data.fs.inode_usage = int( round( data.fs.inodes_used * 100.0 / fssttat.f_files ) )
    print 'INode-Usage:', data.fs.inode_usage, '(%)'
    data.fs.inodes_free = fssttat.f_ffree
    print 'INodes-Free:', data.fs.inodes_free
    data.fs.inode_availability = int( round( 
        fssttat.f_ffree * 100.0 / fssttat.f_files ) )
    print 'INode-Availability:', data.fs.inode_availability, '(%)'
    print '-'*79
    print '='*79
    if bencode:
        print bencode.bencode( data.copy() )

    print complexity( data )
#    print pformat( data.copy() )
#    print json_write( data.copy() )
    
#    print fssttat.f_ffree * 100 / total_nodes

if __name__ == '__main__':
    main()


