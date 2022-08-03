#!/usr/bin/env python3
"""
Helper to get some numbers from Transmission using transmission_rpc library.

The transmission-remote tool that comes with Transmission is much, much faster
however it can not give all the (raw) numbers I want for metrics and monitoring
purposes.

Because other data besides statistics are easily processed with Python and
available from the RPC API/Python library, I added various other actions.
And finally a --help etc. for ease of use to wrap it up.
"""
__usage__ = """
Usage:
    ( --<action> | <action> ) [<Args...>]
    ( -? | -h ) [<command>]
        Print short help
    ( --help )
        Print complete help text
    --commands
    --aliases
"""
import os, sys
from pprint import pprint

import distutils.util
import transmission_rpc
from transmission_rpc import Client


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
    ("Total shareratio",    lambda c, s:
        s.cumulative_stats['uploadedBytes'] / s.cumulative_stats['downloadedBytes']),

    ("Session rx rate",     lambda c, s:
        s.current_stats['downloadedBytes'] / s.current_stats['secondsActive']),
    ("Session tx rate",     lambda c, s:
        s.current_stats['uploadedBytes'] / s.current_stats['secondsActive']),

    ("Delta seconds",       lambda c, s: c.delta_sec),

    ("New rx rate",         lambda c, s:
        ( s.current_stats['downloadedBytes'] - c.last_rx ) / c.delta_sec),
    ("New tx rate",         lambda c, s:
        ( s.current_stats['uploadedBytes'] - c.last_tx ) / c.delta_sec),

    #("Free space",          lambda c, s:
)

def init_client ():
    "Initialize client and fetch session and cumulative stats"
    c = Client()
    c.session_stats()
    return c, c.get_session()

def init_stats (c, s, *fieldids):
    "Get only the stats we need"
    stats = {}
    for field_name, cb in stat_fields:
        field_id = field_name.lower().replace(' ', '_')
        if fieldids and field_id not in fieldids:
            continue
        stats[field_id] = field_name, cb
    return stats


def print_torrent (torrent, c, s, fmt='id-info'):
    numid = torrent.id
    if torrent.error: numid = '%s*' % numid
    if fmt == 'id-info':
        print(numid, torrent.hashString, torrent.name)
    elif fmt == 'download-log':
        td = torrent.date_done - torrent.date_added
        #print( td, 'done:', torrent.date_done,
        #        'started:', torrent.date_started,
        #        'active:', torrent.date_active,
        #        'added:', torrent.date_added )
        if td.days > 0 :
            td_str = "%d:%d:%d" % (td.days, td.seconds/3600, td.seconds%3600/60)
        else:
            td_str = "%d:%d" % (td.seconds/3600, td.seconds%3600/60)
        print(torrent.date_done, td_str, numid, torrent.name)
    elif fmt == 'corrupted-log':
        # Normally date-done is None for torrents with bytes left to download,
        # this is for those invalidated afterwards.
        print(torrent.date_done, numid, torrent.left_until_done, torrent.name)
    elif fmt == 'torrent-status':
        print(numid, torrent.hashString, '%i' % torrent.progress,
                '%i' % torrent.available, end='')
        if torrent.available < 100: print(' incomplete', end='')
        if torrent.is_stalled: print(' stalled')
        else: print()
    elif fmt == 'availability-info':
        print(numid, torrent.hashString,
                '%i' % torrent.available, torrent.name)
    else:
        print(numid)


def parse_bool(spec):
    if isinstance(spec, str):
        return distutils.util.strtobool(spec)
    assert isinstance(spec, bool)
    return spec

def parse_cmdarg(spec):
    return spec.lstrip('-').replace('-', '_')

def get_handlers():
    for k in globals().keys():
        if k.startswith('handle_'):
            yield k


## Command-line action handlers

def handle_active (c, s):
    "Print active-count, indicating count of active torrents."
    handle_stats(c, s, 'active_count')

def handle_get (c, s, idspec, *args):
    "Usage: <Id-Spec> [<Format>]"
    if idspec.isdigit():
        torrent = c.get_torrent(int(idspec))
    else:
        torrent = c.get_torrent(idspec)
    print_torrent(torrent, c, s, *args)

def handle_list (c, s, *args):
    """
    This is by far not as fast as using `transmission-remote -l`, but it does
    show the bt info-hash
    """
    for torrent in c.get_torrents():
        print_torrent(torrent, c, s, *args)
        #if torrent.date_done:
        #    continue
        #print(torrent.date_done)
        #for file_id, file in enumerate(torrent.files()):
        #    print(num, file_id+1, file)
        #pprint(torrent.name)

def handle_downloaded (c, s, ignore_invalid=False):
    """
    List downloads that are done, sorted by their download date.

    Some may be 'complete' but invalidated afterwards, add a 'true' or '1'
    argument to be quiet about those cases. Default is to append them after
    an empty line with different line format (including the missing byte count,
    ie. the length of data where in a corruption occured).
    These are not marked as errors.

    XXX: It may be in these cases that corruption occured at the end?
    After a complete file, before one missing so that the block spanning this
    will never calculate its correct checksum.

    See --invalid for these cases specifically, and --corrupted for any torrent
    that at one point received corrupted data.
    """
    torrents = c.get_torrents()
    if not torrents: return 9
    log = {}
    ignore_invalid = parse_bool(ignore_invalid)
    if not ignore_invalid: problematic = {}
    for torrent in torrents:
        if not torrent.date_done:
            # Torrents without metadata or partial file selections have no
            # left_until_done as well
            continue
        dd = torrent.date_done
        if torrent.left_until_done == 0:
            assert dd not in log, dd
            log[dd] = torrent
        else:
            # XXX: Have a few of these (done-date but also left_until_done)
            # I guess these are completed, and it appears someone send corrupt
            # parts and Transmission noticed after downloding..
            if not ignore_invalid:
                problematic[dd] = torrent

    for dd in sorted(log):
        print_torrent(log[dd], c, s, 'download-log')

    if ignore_invalid:
        return

    problems = len(problematic)
    if problems:
        print ()
        print ("Appending %i items which were downloaded as well, but found invalid." %
                problems, file=sys.stderr)
        for dd in sorted(problematic):
            print_torrent(problematic[dd], c, s, 'corrupted-log')

def handle_downloads (c, s, fmt='torrent-status'):
    """
    List all downloads that have not completed yet, print their progress,
    avalability percentage and also add wether it was ever seen completely, and
    if it is stalled or not. This does not include seeding.

    For downloaded items see --downloaded.

    Also see --availability for a complete list, and --stalled to list state
    of seeding torrents.
    """
    torrents = c.get_torrents()
    if not torrents: return 9
    for torrent in torrents:
        # Finished includes seeding to the global or per-torrent setting,
        # XXX: also less than 100 progress is possibly 'complete' for
        # selective file downloads.
        #if torrent.is_finished or torrent.progress == 100:
        if not torrent.left_until_done:
            continue
        print_torrent(torrent, c, s, fmt)

def handle_errors (c, s, quiet=False):
    """
    List all torrents which are not correctly configured with Transmission.

    For other errors, see --stalled, --invalid and --corrupted.
    """
    torrents = c.get_torrents()
    if not torrents: return 9
    errors = False
    for torrent in torrents:
        if torrent.error:
            if not quiet: print(torrent.id, torrent.error_string)
            if not errors: errors = True
    # Non-zero exit if list was empty
    if not errors: return 1

def handle_availability (c, s, quiet=False):
    """
    Print the ID info with availability for all loaded torrents.
    """
    #torrent.desired_available:
    #   zero if nothing is missing, bytes if parts are unavailable?
    torrents = c.get_torrents()
    if not torrents: return 9
    everything = True
    for torrent in torrents:
        print_torrent(torrent, c, s, 'availability-info')
        if everything and torrent.available < 100:
            everything = False
    if not everything: return 1

def handle_corrupted(c, s):
    "TODO: List torrents that have invalid data."
    torrents = c.get_torrents()
    if not torrents: return 9
    for torrent in torrents:
        # XXX: seem what I look for would be marked as error but can't test
        # and see no other attribute
        print(dir(torrent))
        return

def handle_invalid(c, s, fmt='corrupted-log'):
    "List torrents that are done yet invalid. See also --corrupted."
    torrents = c.get_torrents()
    if not torrents: return 9
    for torrent in torrents:
        if torrent.date_done and torrent.left_until_done != 0:
            print_torrent(torrent, c, s, fmt)

def handle_stalled(c, s, fmt='id-info'):
    """Usage: [<Format>]
    List only torrents that have is-stalled attribute set.
    """
    torrents = c.get_torrents()
    if not torrents: return 9
    for torrent in torrents:
        if torrent.is_stalled:
            print_torrent(torrent, c, s, fmt)

def handle_free_space (c, s, *paths):
    """Usage: [<Paths...>]
    XXX: Location can be anywhere, but it doesn't seem efficient to look at
    every torrent here to list the possible locations."""
    if not paths: paths = [ s.download_dir ]
    for path in paths:
        print(path, c.free_space(path))

def handle_has_errors (c, s):
    "Return non-zero unless there are errors."
    return handle_errors(c, s, True)

def handle_rawobjkeys (c, s):
    """
    Dump keys of API objects to easily check if we missed anything interesting.
    The pydoc's are also a good read.
    """
    pprint((repr(c), type(c), [ k for k in dir(c) if not k.startswith('_') ]))
    pprint((repr(s), type(s), [ k for k in dir(s) if not k.startswith('_') ]))
    # I guess the last torrent is least likely to be deleted?
    # Look for first existing download ID, not sure how else to quickly fetch
    # one torrent.
    t = None
    tid = s.torrentCount
    while tid > 0:
       try:
           t = c.get_torrent(tid)
           break
       except KeyError:
           tid -= 1
    if t:
        pprint((repr(t), type(t), [ k for k in dir(t) if not k.startswith('_') ]))

def handle_rawstats (c, s):
    "Dump session key/values as python dictionary"
    pprint(dict(s.items()))

def handle_rawsession(c, s):
    "Dump string representation of session object"
    print(s)

def handle_shareratios (c, s):
    "Print total- and session-shareratio"
    handle_stats(c, s, 'total_shareratio', 'session_shareratio')

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

def handle_transfer_stats (c, s):
    "Print this sessions number, total runtime seconds and transfer bytes"
    handle_stats(c, s,
            'session_number', 'session_seconds',
            'session_rx_bytes', 'session_tx_bytes')

def handle_stats (c, s, *selectids):
    "Print statistics/metrics with given IDs"
    fmt = os.getenv('FMT', 'text')
    stats = init_stats(c, s, *selectids)
    for field_id in stats:
        v = stats[field_id][1](c, s)
        if fmt == 'text':
            print('%s:' % stats[field_id][0], v)
        elif fmt == 'sh':
            print('%s=%s' % (field_id, v))
        else:
            print(stats[field_id][0], repr(v))

def handle_commands(c, s):
    "List all command actions"
    for h in get_handlers():
        print('--'+h[7:].replace('_', '-'))

def handle_help(c, s, cmd=None):
    "See list of all --commands and --aliases as well."
    global aliases

    if cmd:
        fun = globals()['handle_%s' % parse_cmdarg(cmd)]
        if fun.__doc__:
            alt = None
            for k, alts in aliases.items():
                if cmd == k:
                    alt = v
                    break
            if alt:
                print("Help:", "( %s )" % " | ".join(alt+(cmd,)), end='')
            else:
                print("Help:", cmd, end='')
            print("\n\t", fun.__doc__.strip())
        else:
            return 1
    else:
        print(__usage__)
        print("Aliases:")
        handle_aliases(c, s, "\t")

def handle_aliases(c, s, p=""):
    "List all command aliases"
    for a in aliases:
        print(p+(", ".join(aliases[a]))+':', a)

def handle_long_help(c, s, cmd=None):
    if cmd:
        handle_help(c, s, cmd)
        return
    handle_help(c, s)
    print()
    print("Commands:")
    print()
    for h in get_handlers():
        c = h[7:].replace('_', '-')
        alt = None
        for k, v in aliases.items():
            if c == k:
                alt = v
                break
        if alt:
            print("( %s )" % " | ".join(alt+(c,)))
        else:
            print('--'+c)
        fun = globals()['handle_%s' % parse_cmdarg(c)]
        if fun.__doc__ and fun.__doc__.strip():
            print("\t"+fun.__doc__.strip().replace("\n", "\n\t"))
            print()

aliases = {
        'list': ( 'l', ),
        'get': ( 'g', ),
        'help': ( 'h', '?' ),
        'long-help': ( 'help', 'long-help' ),
    }

if __name__ == '__main__':
    args = sys.argv[1:]
    if args: action = parse_cmdarg(args.pop(0))
    else: action = 'stats'
    for k, v in aliases.items():
        if action in v:
            action = parse_cmdarg(k)
            break
    if action not in ('help', 'long_help',):
        c, s = init_client ()
    else:
        c, s = None, None
    locals()['handle_%s' % action](c, s, *args)
