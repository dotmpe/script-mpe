#!/usr/bin/env python
"""
TODO: reinvent rsr using script libs
TODO: where to store settings, data; need split-settings/composite-db
"""
import os
import shelve
import traceback
from pprint import pformat

import lib
import confparse
from libcmd import Cmd, err
from taxus import Taxus, Node, INode, Volume, get_session


class Rsr(Taxus):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['query']
    DEFAULT_ACTION = 'list_nodes'

    @classmethod
    def get_opts(klass):
        return (
            )

    @staticmethod
    def get_options():
        return Cmd.get_opts() + Taxus.get_opts() + Rsr.get_opts()

    def list_nodes(self, **kwds):
        print self.session.query(Node).all()

    def import_bookmarks(self, args, parse, **kwds):
        print self.session

    # Volume-checksum dev:

    def list_checksums(self):
        pwd = os.getcwd()
        volume = self.find_volume()
        if not volume:
            err("Not in a volume")
            return
        vdb = shelve.open(volume)

        for p in vdb:
            print p, vdb[p]

    def update_volume(self):
        pwd = os.getcwd()
        volume = self.find_volume()
        if not volume:
            err("Not in a volume")
            return
        err("On volume: %r", volume)

        vdb = shelve.open(volume)
        for root, nodes, leafs in os.walk(pwd):
            for leaf in leafs:
                cleaf = os.path.join(root, leaf)
                if not os.path.isfile(cleaf) or os.path.islink(cleaf):
                    err("Ignored non-regular file %r", cleaf)
                    continue
                if Metafile.is_metafile(cleaf):
                    if not Metafile(cleaf).get_file():
                        err("Metafile without resource file")
                else:
                    if Metafile.has_metafile(cleaf):
                        metafile = Metafile(cleaf)
                        # TODO:
        vdb.close()

    def init_volume(self):
        path = os.getcwd()
        cdir = os.path.join(path, '.cllct')
        if not os.path.exists(cdir):
            os.mkdir(cdir)
        vdb = os.path.join(cdir, 'volume.db')
        if os.path.exists(vdb):
            err("DB exists")
            return
        db = shelve.open(vdb)
        #DB_MODE = 'n'
        #db = anydbm.open(vdb, DB_MODE)
        db['mounts'] = [path]

    def find_volume(self):
        vdb = None
        cwd = os.getcwd()
        for path in confparse.find_config_path("cllct", cwd):
            vdb = os.path.join(path, 'volume.db')
            if os.path.exists(vdb):
                break
        return vdb

    # XXX: /Volume-checksum

    

if __name__ == '__main__':
    app = Rsr()
    app.main()


