#! /usr/bin/env python3
# vim:fenc=utf-8
#
# Copyright © 2026 hari <hari@t470p>
#
# Distributed under terms of the MIT license.

"""
"""
import os

from qbittorrentapi import Client

user = os.environ['QBT_API_USER']
# XXX: should use key.. probably
password = os.environ['QBT_API_PASS']

qbt = Client(host='localhost:5430', username=user, password=password)

torrents = qbt.torrents_info()
for t in torrents:

    #print(t)
    if t.progress == 1:
        print(t.hash, t.state, "100%", t.pieces_num, t.pieces_have )
    elif t.progress > 0 and t.progress < 0.1:
        print(t.hash, t.state, ">0.1%", t.pieces_num, t.pieces_have )
    else:
        print(t.hash, t.state, f"{t.progress*100:.1f}%", t.pieces_num, t.pieces_have )
    #print(t.name, t.hash, t.save_path, t.state)


#
