#!/usr/bin/env python
"""
http://stackoverflow.com/questions/2572521/extract-the-sha1-hash-from-a-torrent-file
"""
from __future__ import print_function
import sys, os, hashlib, StringIO, bencode
from pprint import pprint

from hashlib import sha1
from bencode import bdecode as decode, bencode as encode

#import libtorrent as lt


def pieces_generator(info):
    """Yield pieces from download file(s)."""
    piece_length = info['piece length']
    if 'files' in info: # yield pieces from a multi-file torrent
        piece = ""
        for file_info in info['files']:
            path = os.sep.join([info['name']] + file_info['path'])
            print(path)
            # XXX: all files must exist, with missing files pieces overlapping
            #    fileboundaries cannot be validated.
            # It would be nice to validate specific files only, or tolerate
            # missing files. This routine would need to skip certain byte spans
            # and signal main()
            sfile = open(path.decode('UTF-8'), "rb")
            while True:
                piece += sfile.read(piece_length-len(piece))
                if len(piece) != piece_length:
                    sfile.close()
                    break
                yield piece
                piece = ""
        if piece != "":
            yield piece
    else: # yield pieces from a single file torrent
        path = info['name']
        print(path)
        sfile = open(path.decode('UTF-8'), "rb")
        while True:
            piece = sfile.read(piece_length)
            if not piece:
                sfile.close()
                return
            yield piece

def corruption_failure():
    """Display error message and exit"""
    print("download corrupted")
    exit(1)


def read_torrent(torrentfile_path):
    torrent_file = open(torrentfile_path, "rb")
    return decode(torrent_file.read())

def info(torrentfile_path):
    metainfo = read_torrent(torrentfile_path)
    if not 'magnet-info' in metainfo:
        #pprint(metainfo)
        print("Missing 'magnet-info' key %r" % os.path.basename(torrentfile_path))
        sys.exit(1)
    #pprint(metainfo['magnet-info'])

    info = metainfo['magnet-info']['info_hash']

    print("magnet:?xt=urn:btih:%s" % sha1(info).hexdigest())
    print("magnet:?xt=urn:btih:%s" % sha1(encode(info)).hexdigest())


def verify(torrentfile_path):
    metainfo = read_torrent(torrentfile_path)

    if not 'magnet-info' in metainfo:
        print("Missing 'magnet-info' key %r" % os.path.basename(torrentfile_path))
        sys.exit(1)

    print(metainfo)
    info = metainfo['magnet-info']

    if 'files' in info:
        print('info/files', info['files'])

    print('info/piece length', info['piece_length'])
    print('info/name', info['name'])

    pieces = StringIO.StringIO(info['pieces'])
    print(len(info['pieces'])/20, "pieces, piece length:",info['piece length'])

    # Iterate through pieces
    for piece in pieces_generator(info):
        # Compare piece hash with expected hash
        piece_hash = sha1(piece).digest()
        if (piece_hash != pieces.read(20)):
            corruption_failure()

    # ensure we've read all pieces
    if pieces.read():
        corruption_failure()


if __name__ == "__main__":
    argv = list(sys.argv)
    scriptname = argv.pop(0)

    if '-h' in argv:
        print(__doc__)
        sys.exit(0)

    if '--info' in argv:
        pprint(info(argv[1]))
        sys.exit(0)

    if '--dump' in argv:
        # Can't serialize binary string with JSON lib
        #from script_mpe.res import js
        #print(js.dumps(read_torrent(argv[1])))
        pprint(read_torrent(argv[1]))
        sys.exit(0)

    verify(argv.pop(0))
