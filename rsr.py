#!/usr/bin/env python
"""
See Resourcer.rst
"""
import os
import shelve
from pprint import pformat

import lib
import confparse
from libcmd import Cmd, err
from taxus import Taxus, Node, INode, get_session #Volume
from res import PersistedMetaObject, Metafile, Volume


class Rsr(Taxus):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['query']
    DEFAULT_ACTION = 'list_nodes'

    HANDLERS = [
            'cmd:static',
            'cmd:config',
            'cmd:options',
            'taxus:session', # set up SQL session
            'rsr:objects', # set up shelve for use as object cache (objectdb)
            'rsr:volume', # setup shelve for use as volume cache
            'cmd:actions',
            #'taxus:close',
            'rsr:clean',
        ]

    NAMESPACE = lib.RSR_NS

    @classmethod
    def get_opts(klass):
        """
        Return tuples with command-line option specs.
        """
        return (
            )

    @staticmethod
    def get_options():
        """
        Collect all options for the current class if used as Main command.
        """
        return Cmd.get_opts() + Taxus.get_opts() + Rsr.get_opts()

    def rsr_objects(self, opts=None, **kwds):
        """
        Initialize default object store (for rsr.res)
        """
        self.objectdb = PersistedMetaObject.get_store('default', opts.objectdbref)

    def rsr_volume(self, opts=None, **kwds):
        err("Rsr: init volume")
# TODO: use/test for taxus.Volume interface, now uses res.Volume
        volume = Volume.find(os.getcwd())
        if not volume:
            err("Not in a volume")
            return
        err("On volume: %r", volume)
        self.volumedb = PersistedMetaObject.get_store('volume', volume.db)
        err("%i keys", len(self.volumedb))
        #Metafile.default_extension = '.meta'
        #Metafile.basedir = 'media/application/metalink/'

    def rsr_workspace(self, opts=None):
        pass # determine, init dir

    def rsr_content_20(self, opts=None):
        pass # load index

    def rsr_content_sha1(self, opts=None):
        pass # load index
        
    def rsr_clean(self, opts=None, **kwds):#, args):
        vlen = len(self.volumedb)
        err("Rsr: Closing volumedb")
        self.volumedb.close()
        err("Rsr: Closed, %i keys", vlen)
    #
    def list_nodes(self, **kwds):
        print self.session.query(Node).all()

    def import_bookmarks(self):
        """
        Import from
          - HTML
          - Legacy delicious XML
        """
        print self.session
    
    def dump_bookmarks(self):
        pass


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

    def update_volume(self, options=None):
        """
        Walk all files, gather metadata into metafile.

        Create metafile if needed. Fill in 
            - X-First-Seen
        This and every following update also write:
            - X-Last-Update
            - X-Meta-Checksum
        Metafile is reloaded when
            - Metafile modification exceeds X-Last-Update
        Updates of all fields are done when:
            - File modification exceeds X-Last-Modified
            - File size does not match Length
            - If any of above mentioned and at least one Digest field is not present.

        """ 
        pwd = os.getcwd()
        i = 0
        for path in Metafile.walk(pwd):
            i += 1
            new, updated = False, False
            metafile = Metafile(path)
            #if options:
            #metafile.basedir = 'media/application/metalink/'
            #if metafile.key in self.volumedb:
            #    metafile = self.volumedb[metafile.key]
            #    #err("Found %s in volumedb", metafile.key)
            #else:
            #    new = True
            if metafile.needs_update():
                #err("Updating metafile for %s", metafile.path)
                metafile.update()
                update = True
            if metafile.key not in self.volumedb:
                #err("Writing %s to volumedb", metafile.key)
                self.volumedb[metafile.key] = metafile
            if new or updated:
                #if options.persist_meta:
                #if metafile.non_zero:
                #    err("Overwriting previous metafile at %s", metafile.path)
                metafile.write()
                for k in metafile.data:
                    print '\t'+k+':', metafile.data[k]
                print '\tSize: ', lib.human_readable_bytesize(
                    metafile.data['Content-Length'], suffix_as_separator=True)
            else:
                print '\tOK'

    def init_volume(self):
        #PersistedMetaObject.get_store('global')
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
        #DB_MODE = 'n'
        #db = anydbm.open(vdb, DB_MODE)
        db['mounts'] = [path]
        db.close()

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

lib.namespaces.update((Rsr.NAMESPACE,))

if __name__ == '__main__':
    app = Rsr()
    app.main()

