"""
res.ws - work with metadirs as context

Define and manage untracked files, and/or collections of repositories.

XXX: The generic workspace is rooted in .cllct/ws.*id dirs by default.
Based on Workspace, three more specific types are given which all seem to
make some sense but need a bit of additional refinement or coordination. This
is current order of the inheritance ::

  Workspace .cllct/ws.*id
    Workdir .cllct/local.*id
      Homedir .cllct/home.*id
    Volumedir .cllct/vol.*id

Refactoring ideas::

  Workspace .cllct/ws.*id - abstract with basic metadir based tooling
    Workdir .cllct/local.*id - movable user-dir, maybe overlap with volume-dir
    Basedir - tracked workspace, sync, etc. defaults to home?
      Homedir .cllct/home.*id - one per system/user at most
      Volumedir .cllct/vol.*id - one per either physical or storage partition

Workspace has no restrictions: construction, instance count, cardinality etc.
Volume dir is tied to certain paths, mount points specifically, and Homedir
is also prescribed by the host system. Both are basedirs to give them
access to global state. Workdir should represent an adapter to the current
or selected basedir, while Basedir maybe is recursive and includes checkouts.
"""
import os
import anydbm
import shelve

from script_mpe.confparse import Values, YAMLValues

from .persistence import PersistedMetaObject
from .metafile import Metadir
from .vc import Repo
from .js import AbstractYamlDocs
from .fs import Dir


class Workspace(AbstractYamlDocs, Metadir):

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

    @classmethod
    def get_session(klass, scriptname, scriptversion):
        """
        :FIXME:91: setup SA session:
            - load modules needed for script, possibly interdepent modules
            - assert data is at the required schema version using migrate
        """
        raise NotImplementedError()

    def __init__(self, path):
        super(Workspace, self).__init__(path)
        self.load_settings()

    def load_settings(self):
        conf = self.metadirref('yaml')
        if os.path.exists(conf):
            self.settings = YAMLValues.load(conf)
            assert isinstance(self.settings, dict), self.settings
        else:
            self.settings = {}

    @property
    def dbref(self):
        return self.metadirref( 'shelve' )

    def get_yaml(self, name, defaults=None):
        "Override res.js.AbstractYamlDocs.get_yaml"
        p = self.metadirref( 'yaml', name )
        if not os.path.exists(p):
            p = self.metadirref( 'yml', name )
        if defaults != None and not os.path.exists(p):
            self.save_yaml(p, defaults)
        return p

    def relpath(self, topath, basepath=None):
        if not basepath: basepath = self.path
        return os.path.relpath(topath, basepath)

    # XXX: Old PMO stuff

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
        return Values(idcs)

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

    DOC_EXTS = ".rst .md .txt".split(' ')

    def __init__(self, *args, **kwds):
        super(Workdir, self).__init__(*args, **kwds)
        self.doc_exts = self.DOC_EXTS

    def find_docs(self, cwd=None, strict=False):
        if cwd: path = self.relpath(cwd)
        else: path = self.path

        # One filename based filter
        file_fltrs = [ lambda path: os.path.splitext(path)[1] in self.doc_exts ]

        # Change to basedir so that pathiter works
        os.chdir(self.path)
        # FIXME: exclude patterns per set
        Dir.ignore_names = Dir.ignore_names + (
                'requirements*.txt', 'vendor', 'node_modules' )
        # Return generator
        for p in Dir.Walk(path, dict(recurse=True, files=True), (file_fltrs, None)):
            yield p

    def find_scmdirs(self, cwd=None, s=False):
        if cwd:
            path = os.path.realpath(cwd)
            assert path.startswith(self.path)
        else:
            path = self.path
        if Repo.is_repo(path):
            yield path
            return
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
