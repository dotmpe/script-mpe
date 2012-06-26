"""
Read metadata from metafiles.

- Persist composite objects
- Metalink4 <-> HTTPResponseHeaders

- Content-*

"""
import os


import iface
#import lib
import confparse
#from taxus import get_session
import log

import lib
import util
from persistence import PersistedMetaObject
from fs import File, Dir
from mime import MIMEHeader
from metafile import Metafile



class SHA1Sum(object):
    checksums = None
    def __init__(self):
        self.checksums = {}
    def parse_data(self, lines):
        for line in lines:
            p = line.find(' ')
            checksum, filepath = line[:p].strip(), line[p+1:].strip()
            self.checksums[checksum] = filepath
    def __iter__(self):
        return iter(self.checksums)
    def __getitem__(self, checksum):
        return self.checksums[checksum]


#class HTTPHeader(MIMEHeader):
#    pass
#
#class HTTPResponse(HTTPHeader):
#    pass


class Workspace(object):

    def __init__(self, path):
        self.name = os.path.basename(path)
        self.path = os.path.dirname(path)

    @property
    def full_path(self):
        return os.path.join(self.path, self.name)

    def __str__(self):
        return "[%s %s %s]" % (self.__class__.__name__, self.path, self.name)


class Volume(Workspace):

    def __str__(self):
        return repr(self)

    def __repr__(self):
        return "<Volume 0x%x at %s>" % (hash(self), self.db)

    @property
    def db(self):
        return os.path.join(self.full_path, 'volume.db')

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
            return Volume(path)


class Repo(PersistedMetaObject):
  
    def __init__(self, path, uri=None, rtype=None):
        assert os.path.isdir(path), path
        self.path = path
        if not rtype:
            rtype = self.__class__.get_type(path)
        self.rtype = rtype
        if not uri:
            uri = self.__class__.get_reporef(path)
        self.uri = uri
    # PersistedMetaObject

    @property
    def key(self):
        """
        Repo belong to a directory. The Key ID is the MD5 digest of its path.
        """
        return hashlib.md5(self.path).hexdigest()

    #

    # Static

    repo_match = (
            ".git",
            ".svn",
            ".bzr",
            ".hg"
        )

    repo_type = {
            'GIT': ['.git',],
            'Subversion': ['.svn',],
            'BazaarNG': ['.bzr',],
            'Mercurial': ['.hg',],
        }

    @classmethod
    def is_repo(klass, path):
        return klass.get_type(path) != None

    @classmethod
    def get_type(klass, path):
        for n in klass.repo_match:
            if os.path.exists(os.path.join(path, n)):
                for t in klass.repo_type:
                    if n in klass.repo_type[t]:
                        return t

    @classmethod
    def get_reporef(klass, path, rtype=None):
        if not rtype:
            rtype = klass.get_type(path)
        return getattr(klass, 'get_reporef_'+rtype)(path)

    @classmethod
    def get_reporef_Subversion(klass, path):
        return lib.cmd("cd %s;svn info | grep URL\: | sed 's/[^:]*\: //'",
                path).strip()
        
    @classmethod
    def get_reporef_GIT(klass, path):
        r = lib.cmd("cd %s;git remote -v", path)\
                .strip().split('\n')
        while r:
            ri = r.pop(0)
            if 'fetch' in ri:
                return ri.split('\t')[1].split(' ')[0]

    @classmethod
    def get_reporef_BazaarNG(klass, path): 
        pass

    @classmethod
    def get_reporef_Mercurial(klass, path): 
        pass

    @classmethod
    def walk(klass, path, bare=False, max_depth=-1):
        # XXX: may rewrite to Dir.walk
        """
        Walk all files that may have a metafile, and notice any metafile(-like)
        neighbors.
        """
        assert not bare, 'TODO'
        for root, nodes, leafs in os.walk(path):
            for node in list(nodes):
                dirpath = os.path.join(root, node)
                assert Dir.sane(dirpath), dirpath
                if not os.path.exists(dirpath):
                    log.err("Error: reported non existant node %s", dirpath)
                    nodes.remove(node)
                    continue
                depth = dirpath.replace(path,'').strip('/').count('/')
                if Dir.ignored(dirpath):
                    log.err("Ignored directory %r", dirpath)
                    nodes.remove(node)
                    continue
                elif max_depth != -1:
                    if depth >= max_depth:
                        nodes.remove(node)
                        continue
                if klass.is_repo(dirpath):
                    nodes.remove(node)
                    yield Repo(dirpath)



