#!/usr/bin/env python3
import os, sys
from pprint import pprint

import transmission_rpc
from transmission_rpc import Client
import requests


stat_fields = (
    ("Torrent count",       lambda c, s: s.torrentCount),
    ("Active count",        lambda c, s: s.activeTorrentCount),
    ("Session number",      lambda c, s: s.cumulative_stats['sessionCount']),

    ("Total seconds",       lambda c, s: s.cumulative_stats['secondsActive']),
    ("Session seconds",     lambda c, s: s.current_stats['secondsActive']),

    ("Total file count",    lambda c, s: s.cumulative_stats['filesAdded']),
    ("Session file count",  lambda c, s: s.current_stats['filesAdded']),

    ("Total rx bytes",      lambda c, s: s.cumulative_stats['downloadedBytes']),
    ("Total tx bytes",      lambda c, s: s.cumulative_stats['uploadedBytes']),
    ("Session rx bytes",    lambda c, s: s.current_stats['downloadedBytes']),
    ("Session tx bytes",    lambda c, s: s.current_stats['uploadedBytes']),

    ("Session shareratio",  lambda c, s:
        s.current_stats['uploadedBytes'] / s.current_stats['downloadedBytes']),
    ("Total shareratio", lambda c, s:
        s.cumulative_stats['uploadedBytes'] / s.cumulative_stats['downloadedBytes']),

    ("Session rx rate",     lambda c, s:
        s.current_stats['downloadedBytes'] / s.current_stats['secondsActive']),
    ("Session tx rate",     lambda c, s:
        s.current_stats['uploadedBytes'] / s.current_stats['secondsActive']),

    ("Delta seconds",       lambda c, s: c.delta_sec),

    ("New rx rate",         lambda c, s: (
        s.current_stats['downloadedBytes'] - c.last_rx ) / c.delta_sec
    ),
    ("New tx rate",     lambda c, s: (
        s.current_stats['uploadedBytes'] - c.last_tx ) / c.delta_sec
    ),
)

def init_client ():
    c = Client() #username='trim21', password='123456')
    c.session_stats()
    return c, c.get_session()

def init_stats (c, s, *fieldids):
    stats = {}
    for field_name, cb in stat_fields:
        field_id = field_name.lower().replace(' ', '_')
        if fieldids and field_id not in fieldids:
            continue
        stats[field_id] = field_name, cb
    return stats


def handle_rawstats (c, s):
    pprint(dict(s.items()))

def handle_rawsession(c, s):
    print(s)
    pprint(dir(s))

def handle_stats (c, s, *selectids):
    fmt = os.getenv('FMT', 'text')
    stats = init_stats(c, s, *selectids)
    for field_id in stats:
        v = stats[field_id][1](c, s)
        if fmt == 'text':
            print('%s:' % stats[field_id][0], v)
        elif fmt == 'sh':
            print('%s=%s' % (field_id, v))

def handle_list (c, s):
    for num in range(1, s.torrentCount):
        torrent = c.get_torrent(num)
        #if torrent.date_done:
        #    continue
        #print(torrent.date_done)
        for file_id, file in enumerate(torrent.files()):
            print(num, file_id+1, file)

def handle_active (c, s):
    handle_stats(c, s, 'active_count')

def handle_shareratios (c, s):
    handle_stats(c, s, 'total_shareratio', 'session_shareratio')

def handle_transfer_stats (c, s):
    "Print this sessions number, total runtime seconds and transfer bytes"
    handle_stats(c, s,
            'session_number', 'session_seconds',
            'session_rx_bytes', 'session_tx_bytes')

def handle_transfer_rates (c, s):
    "Print transfer rates (bytes/second floating point) since session start"
    handle_stats(c, s, 'session_rx_rate', 'session_tx_rate')

def handle_transfer_rates_since (c, s, since_seconds, last_rx, last_tx):
    "Print rates since last measurement"
    c.delta_sec = s.current_stats['secondsActive'] - int(since_seconds)
    c.last_rx = int(last_rx)
    c.last_tx = int(last_tx)
    handle_stats(c, s,
            'session_number', 'session_seconds',
            'session_rx_bytes', 'session_tx_bytes',
            'delta_seconds', 'new_rx_rate', 'new_tx_rate')


if __name__ == '__main__':
    args = sys.argv[1:]
    if args: cmd = args.pop(0)
    else: cmd = 'stats'
    c, s = init_client ()
    locals()['handle_%s' % cmd](c, s, *args)
