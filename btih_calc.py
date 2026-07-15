#!/usr/bin/env python3
# vim:fenc=utf-8
#
# Copyright © 2026 hari <hari@t470p>
#
# Distributed under terms of the MIT license.

import sys
import hashlib
import bencoding
from pathlib import Path

def get_infohash(torrent_path):
    with open(torrent_path, 'rb') as f:
        metainfo = bencoding.bdecode(f.read())
    info = metainfo[b'info']
    info_hash = hashlib.sha1(bencoding.bencode(info)).hexdigest()
    return info_hash.upper()  # or .lower()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 calc_btih.py <torrentfile> [more files...]")
        sys.exit(1)
    for arg in sys.argv[1:]:
        path = Path(arg)
        if path.is_file() and path.suffix == '.torrent':
            try:
                ih = get_infohash(path)
                #print(f"{path.name}: {ih.lower()}")
                print(ih.lower())
            except Exception as e:
                print(f"Error processing {path}: {e}")
