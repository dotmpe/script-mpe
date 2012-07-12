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


class Volume(Workspace):

    indices = (
            'pwd',
        )

#    def __str__(self):
#        return repr(self)
#
#    def __repr__(self):
#        return "<Volume 0x%x at %s>" % (hash(self), self.db)

#    @property
#    def db(self):
#        return os.path.join(self.full_path, 'volume.db')

    @classmethod
    def find(clss, dirpath):
        path = None
        for path in confparse.find_config_path("cllct", dirpath):
            vdb = os.path.join(path, 'volume.db')
            if os.path.exists(vdb):
                break
            else:
                path = None
        if path:
            return PersistedMetaObject.find('user-volumes', 'pwd', path, Volume)
        #    return Volume(path)
        


