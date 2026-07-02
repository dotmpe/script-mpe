#! /usr/bin/env python3
# vim:fenc=utf-8
#
# Copyright © 2026 hari <hari@t470p>
#
# Distributed under terms of the MIT license.
"""
This uses libtorrent, a P2P client which is inconvenient for simple checking but
I wanted to look at the data and check out setting up a client with urwid. Have
not looked after way to speed up, but shutdown is delaying unreasonable amount
of time for this task.
"""
import time
import signal
import os
import sys
import urwid
import libtorrent as lt

palette = [
    ('normal', 'dark blue', 'black'),
    ('complete', 'dark green', 'white'),
]

def update_progress(ctx, user_data):
    ses, handle, loop, progress = user_data
    s = handle.status()
    if s.state in (
        lt.torrent_status.checking_resume_data,
        lt.torrent_status.checking_files
    ):
        progress.set_completion(s.progress * 100)
        loop.set_alarm_in(0.04, update_progress, user_data)
    else:
        # ses.remove_torrent(handle)
        # loop.stop()
        # print(s.pieces)  # list of bools per piece
        if handle.is_valid():
            sys.exit(0)
        else:
            sys.exit(1)


def verify(torrent_file, save_path):
    signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))  # or handle.abort()

    ses = lt.session()
    params = lt.add_torrent_params()
    params.ti = lt.torrent_info(torrent_file)
    params.save_path = save_path

    handle = ses.add_torrent(params)

    progress = urwid.ProgressBar('normal', 'complete')

    loop = urwid.MainLoop(urwid.Filler(progress), palette=palette)
    loop.set_alarm_in(0.04, update_progress, (ses, handle, loop, progress))
    loop.run()


if __name__ == "__main__":
    argv = sys.argv[:]
    scriptname = argv.pop(0)
    if '-h' in argv:
        print(__doc__)
        sys.exit(0)

    torrent = argv.pop(0)
    if len(argv):
        path = argv.pop(0)
    else:
        path = os.getcwd()
    verify(torrent, path)

