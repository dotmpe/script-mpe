import os

from persistence import PersistedMetaObject


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




