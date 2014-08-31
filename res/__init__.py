"""
res - Read metadata from metafiles.

Classes to represent a file or cluster of files from which specific metadata
may be derived. The objective is using this as a toolkit, to integrate into
programs that work on metadata and/or (media) files.

TODO:
- Persist composite objects:
- Metalink reader/adapter. Metalink4 <-> HTTPResponseHeaders
- Content-* properties
"""
import os
import uuid
import anydbm
import shelve

from script_mpe import confparse
#from script_mpe import lib
#from script_mpe from taxus import get_session
from script_mpe import log

import iface
import util
from persistence import PersistedMetaObject
from fs import File, Dir
from mime import MIMEHeader
from metafile import Metafile, Metadir, Meta, SHA1Sum
from jrnl import Journal
from vc import Repo


"""

Registry
    handler class
        handler name -> 
    
    Volume
        rsr:sha1sum
        rsr:sprssum

    Mediafile
        rsr:metafile
        txs:volume
        txs:workspace

"""


class Workspace(Metadir):

    """
    Workspaces are metadirs with settings, loaded from DOTID '.yaml',
    and a PersistedMetaObject stored in DOTID '.shelve'.

    It also facilitates
    """

    DOTDIR = 'cllct'
    DOTID = 'ws'

    index_specs = [
        ]

    def __init__(self, path):
        super(Workspace, self).__init__(path)
        self.store = None
        self.indices = {}
        conf = self.metadirref('yaml')
        if os.path.exists(conf):
            self.settings = confparse.YAMLValues.load(conf)
        else:
            self.settings = {}

    @property
    def dbref(self):
        return self.metadirref( 'shelve' )

    def init_store(self, truncate=False): 
        assert not truncate
        return PersistedMetaObject.get_store(
                name=Metafile.storage_name, dbref=self.dbref)
        #return PersistedMetaObject.get_store(name=self.dotdir, dbref=self.dbref, ro=rw)
    # TODO: move this, res.dbm.MetaDirIndex
    def init_indices(self, truncate=False):
        flag = truncate and 'n' or 'c'
        idcs = {}
        for name in self.__class__.index_specs:
            ref = self.idxref(name)
            if ref.endswith('.db'):
                idx = anydbm.open(ref, flag)
            elif ref.endswith('.shelve'):
                idx = shelve.open(ref, flag)
            idcs[name] = idx
        return confparse.Values(idcs)


class Homedir(Workspace):

    """
    A workspace that is not a swappable, movable volume, but one that is 
    fixed to a host and exists as long as the host system does. 
    """

    DOTID = 'homedir'

    # XXX:
    htdocs = None # contains much of the rest of the personal workspace stuff
    projects = None # specialized workspace for projects..


class Projectdir(Workspace):

    DOTID = 'project'


class Volumedir(Workspace):

    """
    A specific workspace used to distinguish media volumes (disk partitions,
    network drives, etc).
    """

    DOTID = 'vol'

    index_specs = [
                'sparsesum',
                'sha1sum',
                'dirs'
            ]

    def pathname(self, name, basedir=None):
        if basedir and basedir.startswith(self.path):
            path = basedir[len(self.path.rstrip('/'))+1:]
        else:
            path = ""
        return os.path.join(path, name)

def read_unix(path):
    """
    Return true lines, dropping comments and whitespace lines.
    """
    r = []
    for l in open(path).readlines():
        if l.strip().startswith('#') or not l.strip():
            continue
        r.append(l.rstrip()) # leave indent
    return r

def read_idfile(path):
    """
    Return ID part and optional title part.
    """
    if not os.path.exists(path):
        raise Exception("UNID file missing %s" % path)
    idlines = read_unix(path)
    if not idlines:
        raise Exception("UNID missing in %s" % path)
    if len(idlines) > 1:
        raise Exception("Extraneous content in UNID file %s" % path)
    unid, title = idlines[0], None
    index = unid.find(' ')
    if index:
        unid, title = unid[:index], unid[index+1:]
    return unid, title

