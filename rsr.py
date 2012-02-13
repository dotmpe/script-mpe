#!/usr/bin/env python
"""
TODO: reinvent rsr using script libs
TODO: where to store settings, data; need split-settings/composite-db
"""
import os
import shelve
from pprint import pformat

import lib
import confparse
from libcmd import Cmd, err
from taxus import Taxus, Node, INode, Volume, get_session
from res import PersistedObject, Metafile


class Rsr(Taxus):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['query']
    DEFAULT_ACTION = 'list_nodes'

    main_handlers = [
            #'main_config',
            'main_session', # set up SQL session
            'main_objects', # set up shelve for use as object cache (objectdb)
            'main_volume', # setup shelve for use as volume cache
            'main_run_actions',
            'main_clean',
        ]

    @classmethod
    def get_opts(klass):
        return (
            )

    @staticmethod
    def get_options():
        return Cmd.get_opts() + Taxus.get_opts() + Rsr.get_opts()

    #
    def main_objects(self, opts, args):
        """
        Initialize default object store (for rsr.res)
        """
        self.objectdb = PersistedObject.get_store('default', opts.objectdbref)

    def main_volume(self, opts, args):
        volume = self.find_volume()
        if not volume:
            err("Not in a volume")
            return
        err("On volume: %r", volume)
        self.volumedb = PersistedObject.get_store('volume', volume)

    def main_clean(self, opts, args):
        self.volumedb.close()
    #
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

    def update_volume(self):#, options):
        pwd = os.getcwd()
        for path in Metafile.walk(pwd):
            metafile = Metafile(path)
            if metafile.key in self.volumedb:
                metafile = self.volumedb[metafile.key]
            if metafile.needs_update():
                metafile.update()
            #if options.persist_meta:
            metafile.write()
            if metafile.key not in self.volumedb:
                self.volumedb[metafile.key] = metafile

    def init_volume(self):
        #PersistedObject.get_store('global')
        path = os.getcwd()
        #Volume.create(path)
        cdir = os.path.join(path, '.cllct')
        if not os.path.exists(cdir):
            os.mkdir(cdir)
        vdb = os.path.join(cdir, 'volume.db')
        if os.path.exists(vdb):
            err("DB exists")
            return
        db = shelve.open(vdb)
        db.close()
        #db['mounts'] = [path]

    def find_volume(self):
        vdb = None
        cwd = os.getcwd()
        for path in confparse.find_config_path("cllct", cwd):
            vdb = os.path.join(path, 'volume.db')
            if os.path.exists(vdb):
                break
        return vdb

    def count_volume_files(self):
        print len(self.volumedb.keys())
    # XXX: /Volume-checksum


if __name__ == '__main__':
    app = Rsr()
    app.main()

