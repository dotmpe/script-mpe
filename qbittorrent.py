#! /usr/bin/env python3
# vim:fenc=utf-8
#
# Copyright © 2026 hari <hari@t470p>
#
# Distributed under terms of the MIT license.

"""
"""
import os, sys

from qbittorrentapi import Client

#user = os.environ['QBT_API_USER']
#password = os.environ['QBT_API_PASS']
#qbt = Client(host='localhost:5430', username=user, password=password)
api_key = os.environ['QBT_API_KEY']
qbt = Client(host='localhost:5430', api_key=api_key)

#added_on completed_on last_activity
#name save_path
#category comments

torrents = qbt.torrents_info()
for t in torrents:

    #print(t)
    #sys.exit(1)
    if t.progress == 1:
        print(t.hash, t.state, "100%", t.pieces_num, '-', t.save_path, t.name )
    elif t.progress > 0 and t.progress < 0.1:
        print(t.hash, t.state, ">0.1%", t.pieces_num, t.pieces_have,
              t.save_path, t.name  )
    else:
        print(t.hash, t.state, f"{t.progress*100:.1f}%", t.pieces_num,
              t.pieces_have, t.save_path, t.name )
    #print(t.name, t.hash, t.save_path, t.state)


#
