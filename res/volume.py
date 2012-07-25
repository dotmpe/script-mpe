import os
import confparse
from persistence import PersistedMetaObject


class Workspace(PersistedMetaObject):

    def __init__(self, path):
        self.name = os.path.basename(path)
        self.path = os.path.dirname(path)

    @property
    def full_path(self):
        return os.path.join(self.path, self.name)

    def __str__(self):
        return "[%s %s %s]" % (self.__class__.__name__, self.path, self.name)

    def key(self):
        return self.name


class Volumes(PersistedMetaObject):

    """
    Container for metadata on volumes/workspaces.
    """

    indices = (
            'pwd',
        )


class Volume(Workspace):

    """
    Container for metafiles.
    """

    indices = (
            'inode',
            'sha1_content_digest',
            'md5_content_digest',
        )

    def __str__(self):
        return repr(self)

    def __repr__(self):
        return "<Volume 0x%x at %s>" % (hash(self), self.db)

    @property
    def db(self):
        return os.path.join(self.full_path, 'volume.db')

    @classmethod
    def find(Klass, dirpath):
        path = None
        for path in confparse.find_config_path("cllct", dirpath):
            vdb = os.path.join(path, 'volume.db')
            if os.path.exists(vdb):
                break
            else:
                path = None
        if path:
            return PersistedMetaObject.find('user-volumes', 'pwd', path, Volume)
        
    @classmethod
    def init(Klass, dirpath, lib, settings):
        cdir = os.path.join(dirpath, settings.lib.paths.localdir)
        if not os.path.exists(cdir):
            os.mkdir(cdir)
        dbpath = os.path.join(cdir, 'volume.db')
        if os.path.exists(dbpath):
            log.warn("DB exists at %s", dbpath)
# initialize DB
        vdb = PersistedMetaObject.get_store('volume', dbpath)
        if 'mounts' not in lib.store.volumes:
            lib.store.volumes['mounts'] = []
        volumes = lib.store.volumes['mounts']
        if dbpath not in volumes:
            volumes.append(dbpath)
            lib.store.volumes['mounts'] = volumes
            lib.store.volumes.commit()
        yield Keywords(lib=dict(stores=dict(volume=vdb)))
        
