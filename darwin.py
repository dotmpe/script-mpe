#!/usr/bin/env python
""":created: 2017-04-23
"""
__description__ = "darwin - "
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Usage:
  darwin.py [options] plist-dump PLIST
  darwin.py [options] plist-items PLIST KEY...
  darwin.py [options] spserialata-disk PLIST DISK KEY...
  darwin.py [options] spserialata-disk-part PLIST KEY...
  darwin.py [options] spstorage-disk PLIST DISK KEY...
  darwin.py [options] spstorage-disk-part PLIST KEY...
  darwin.py [options] spusb-disk PLIST DISK KEY...
  darwin.py [options] spusb-disk-part PLIST KEY...

Options:
    -h --help     Show this usage description.
    --version     Show version (%s).
""" % ( __version__ )

import datetime
import os
import re

import confparse
import pbPlist
from pprint import pprint, pformat

import res.js
import log
import util
import reporter


def plst_dump(plst):
    data = eval(repr(plst))
    confparse.yaml_safe_dump(data, sys.stdout, default_flow_style=False)


def cmd_plist_items(PLIST, KEY, settings):
    plst = pbPlist.pbPlist.PBPlist(PLIST)
    i = 0
    for item in plst.root[0]['_items']:
        i += 1
        print i,
        for k in KEY:
            print item[k],
        print


def cmd_plist_dump(PLIST, settings):
    plst = pbPlist.pbPlist.PBPlist(PLIST)
    print len(plst.root)
    plst_dump(plst.root[0])


def cmd_spserialata_disk(PLIST, DISK, KEY, settings):
    plst = pbPlist.pbPlist.PBPlist(PLIST)
    #plst_dump(plst.root[0])
    for adapter in plst.root[0]['_items']:
        for disk in adapter['_items']:
            if 'bsd_name' not in disk or not disk['bsd_name']:
                continue
            if DISK and disk['bsd_name'] != DISK:
                continue
            #plst_dump(disk)
            for k in KEY:
                if k in disk:
                    print disk[k],
                else:
                    print "",
            print
            return
    if DISK:
        return 1


def cmd_spserialata_disk_part(PLIST, KEY, settings):
    plst = pbPlist.pbPlist.PBPlist(PLIST)
    #plst_dump(plst.root[0])
    for adapter in plst.root[0]['_items']:
        for disk in adapter['_items']:
            for volume in disk['volumes']:
                #plst_dump(volume)
                for k in KEY:
                    if k in volume:
                        print volume[k],
                    else:
                        print "",
                print


def cmd_spusb_disk(PLIST, DISK, KEY, settings):
    """
    Find USB device with BSD disk name.
    """
    plst = pbPlist.pbPlist.PBPlist(PLIST)
    for disk in plst.root[0]['_items']:
        for device in disk['_items']:
            if 'bsd_name' not in device or not device['bsd_name']:
                continue
            if DISK and device['bsd_name'] != DISK:
                continue
            #plst_dump(device)
            for k in KEY:
                if k in device:
                    print device[k],
                else:
                    print "",
            print
            return
    if DISK:
        return 1


def cmd_spusb_disk_part(PLIST, KEY, settings):
    plst = pbPlist.pbPlist.PBPlist(PLIST)
    #plst_dump(plst.root[0])
    for disk in plst.root[0]['_items']:
        for volume in disk['volumes']:
            #plst_dump(volume)
            for k in KEY:
                if k in volume:
                    print volume[k],
                else:
                    print "",
            print


def cmd_spstorage_disk(PLIST, DISK, KEY, settings):
    plst = pbPlist.pbPlist.PBPlist(PLIST)
    for storage in plst.root[0]['_items']:
        if 'bsd_name' not in storage or not storage['bsd_name']:
            continue
        if DISK and storage['bsd_name'] != DISK:
            continue
        for k in KEY:
            if k in storage:
                print storage[k],
            else:
                print "",
        print
    if DISK:
        return 1



### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    #opts.default = 'info'
    return util.run_commands(commands, settings, opts)

def get_version():
    return 'darwin.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))

