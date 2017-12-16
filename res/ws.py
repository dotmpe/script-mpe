import os
import anydbm
import shelve

from script_mpe import confparse
from script_mpe.confparse import yaml_load, yaml_dumps

from persistence import PersistedMetaObject
from metafile import Metadir
from vc import Repo



class Workspace(Metadir):

    """
    Workspaces are containers for specifically structured and tagged
    subtrees. Several subtypes are defined to deal with various types of working
    directories.

    Workspaces are metadirs with settings, loaded from DOTID '.yaml',
    and a PersistedMetaObject stored in DOTID '.shelve'.
    """

    DOTNAME = 'cllct'
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
            assert isinstance(self.settings, dict), self.settings
        else:
            self.settings = {}

    @classmethod
    def get_session(klass, scriptname, scriptversion):
        """
        :FIXME:91: setup SA session:
            - load modules needed for script, possibly interdepent modules
            - assert data is at the required schema version using migrate
        """

    @property
    def dbref(self):
        return self.metadirref( 'shelve' )

    def get_yaml(self, name, defaults=None):
        p = self.metadirref( 'yaml', name )
        if not os.path.exists(p):
            p = self.metadirref( 'yml', name )
        if defaults and not os.path.exists(p):
            confparse.yaml_dump(open(p, 'w+'), defaults)
        return p

    def load_yaml(self, name, defaults=None):
        p = self.get_yaml(name, defaults=defaults)
        return confparse.yaml_load(open(p))

    def yamldoc(self, name, defaults=None):
        if name.endswith('doc'):
            a = name
        else:
            a = name+'doc'
        assert not hasattr(self, a), name
        doc = self.load_yaml(name, defaults=defaults)
        setattr(self, a, doc)

    def yamlsave(self, name, **kwds):
        doc = getattr(self, name)
        p = self.get_yaml(name)
        confparse.yaml_dump(open(p,'w+'), doc, **kwds)

    def relpath(self, pwd='.'):
        #cwd = os.path.normpath(os.path.realpath(pwd))
        # going to have todo something more sophisticated
        #assert cwd.startswith(self.path), ( pwd, cwd, self.path )
        cwd = os.path.abspath(os.path.normpath(pwd))
        assert cwd.startswith(self.path), ( pwd, cwd, self.path )
        return cwd[len(self.path)+1:]

    def init_store(self, truncate=False):
        assert not truncate
        return PersistedMetaObject.get_store(
                name=self.storage_name, dbref=self.dbref)
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

    @classmethod
    def find(Klass, *paths):
        for idfile in Klass.find_id(*paths):
            yield os.path.dirname( os.path.dirname( idfile ))
        for metafile in Klass.find_meta(*paths):
            yield os.path.dirname( metafile )


class Workdir(Workspace):

    """
    A user basedir ... ?
    """

    DOTID = 'local'
    projects = [] #

    def find_scmdirs(self, cwd=None, s=False):
        if cwd:
            path = os.path.realpath(cwd)
            assert path.startswith(self.path)
        else:
            path = self.path
        for r in Repo.walk(path, s=s):
            assert r.startswith(path)
            if not s: print(r)
            yield r

    def find_untracked(self, cwd=None, s=False):
        if cwd:
            cwd = os.path.realpath(cwd)
            assert cwd.startswith(self.path)
        for r in Repo.walk_untracked(self.path, s=s):
            if not cwd or r.startswith(cwd):
                if not s: print(r)
                yield r

    def find_excluded(self, cwd=None, s=False):
        if cwd:
            cwd = os.path.realpath(cwd)
            assert cwd.startswith(self.path)
        for r in Repo.walk_excluded(self.path, s=s):
            if not cwd or r.startswith(cwd):
                if not s: print(r)
                yield r


class Homedir(Workdir):

    """
    The default workspace for a user. If no other workspace type applies, the
    Homedir workspace has a user-configured, generic resource collection type.

    XXX: It is a workspace that is not a swappable, movable volume, but one that is
    fixed to a host and exists as long as the host system does.
    TODO: it shoud be aware of other host having a Homedir for current user.
    """

    DOTID = 'home'

    # XXX:
    htdocs = None # contains much of the rest of the personal workspace stuff
    default_projectdir = None # specialized workspace for projects..

    @classmethod
    def find(klass, *paths):
        for idfile in klass.find_id(*paths):
            yield os.path.dirname( os.path.dirname( idfile ))
        for metafile in klass.find_meta(*paths):
            yield os.path.dirname( metafile )
        yield os.path.expanduser('~')



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
