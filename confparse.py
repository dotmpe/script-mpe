"""confparse - persisted metadata

This module stores and loads configuration settings. Once loaded,
confparse._.name provides access to the structure from storage (see Values)
Structure may consist of dictionaries, lists and primitive values.

expand_config_path(leafname)
    Search all parent directories for `leafname`. Returns all existing paths
    considering the given name and a set of prefixes and suffixes.

script.config.suffix
    A list of

Flavours:
    - Python source
    - YAML
    - Filetree

Consider:

- Keys can contain periods ('.'), but in the configuration these will always be
  expanded to module attributes, and thus serialized to nested dictionaries.
- Handling of lists is fairly primitive and could be buggy in cases? Recursion
  depth is fixed by implementation at 2 levels for complex objects in lists.

TODO: segment configuration into multiple files.
"""
import collections
import os, re, sys, types, inspect
from os import unlink, removedirs, makedirs, tmpnam, chdir, getcwd
from os.path import join, dirname, exists, isdir, realpath, splitext
from pprint import pformat

try:
    import syck
    yaml_load = syck.load
    yaml_dump = syck.dump
except ImportError, e:
    try:
        import yaml
        yaml_load = yaml.load
        yaml_dump = yaml.dump
    except ImportError, e:
        print >>sys.stderr, "confparse.py: no YAML parser"


_ = None
"In-mem. settings. "

_paths = {}
"Source-paths for settings. "

name_prefixes = (
    '',  # local (cwd) name
    '.', # local hidden name
#    '.cllct/', # local hidden dir
)

path_prefixes = (
    '~/', # hidden name in $HOME
    '/etc/' # name in /etc/
    '/etc/default/' # name in /etc/
)

name_suffixes = (
    '',
    '.yaml',
    '.conf',
)


def tree_paths(path):

    """
    Yield all paths traversing from path to root.
    """

    parts = path.strip(os.sep).split(os.sep)
    while parts:
        cpath = join(*parts)
        if path.startswith(os.sep):
            cpath = os.sep+cpath
        
        yield cpath
        parts.pop()


def expand_config_path(name, paths=path_prefixes):

    """
    Yield all existing file paths. See `confparse.path_prefixes` for search path.
    Defers to find_config_path.
    """

    return find_config_path(name, path=getcwd(), paths=list(paths))


def find_config_path(markerleaf, path=None, prefixes=name_prefixes,
        suffixes=name_suffixes, paths=[], exists=os.path.exists):

    """
    Search paths for markerleaf with prefixes/suffixes. Yields only existing
    paths. The sequence is depth-first.
    Expands '~/' and '~`username`/' sequences.

    Defaults:
        Prefix: '', '.'
        Path: '~/', '/etc/'
        Suffix: '', '.yaml', '.conf'

    Path, if given, should be a directory. And/or a list of paths may be given
    if that is more convenient. The result is that the search runs in sequence
    from one or more directories.

    Rationale
    ---------
    It is useful to find paths with name `markerleaf`, starting at a certain
    point in the tree and traversing upwards. Prefix and suffix lists add further
    flexibility which usually equals the abilitiy to match both hidden and
    non-hidden filenames, and to match any set of giving filename extensions.
    """
    assert isinstance(markerleaf, basestring), markerleaf
    if path:
        paths.append(path)
    # Get a list of all paths, parents, symlinked locations
    expanded_paths = []
    for p in paths:
        expanded_paths.extend(tree_paths(p))
    # test for existing markerleaf
    while expanded_paths:
        cpath = expanded_paths.pop(0)
        for prefix in prefixes:
            for suffix in suffixes:
                #print (cpath, prefix, suffix,)
                cleaf = markerleaf
                if not markerleaf.startswith(prefix):
                    cleaf = prefix + markerleaf
                if not markerleaf.endswith(suffix):
                    cleaf += suffix
                cleaf = os.path.expanduser(os.path.join(cpath, cleaf))
                if not exists or exists(cleaf):
                    yield cleaf


class DictDeepUpdate:

    @classmethod
    def update(Klass, sub, data):
        for k, v in data.iteritems():
            if isinstance(v, collections.Mapping):
                r = Klass.update(sub.get(k, {}), v)
                sub[k] = r
            elif isinstance(v, list):
                if k in sub:
                    assert isinstance(sub[k], list)
                else:
                    sub[k] = []
                sub[k].extend(v)
            else:
                sub[k] = data[k]
        return sub


class Values(dict):

    """
    Holds configuration settings once loaded.

    FIXME: this is used a lot as a simple attribute-access dict, 
    asbtract this for that use too.
    """

    default_source_key = 'config_file'
    default_config_key = 'default'
#
#    def keys(self):
#        return [x for x in self.__dict__ if not x.startswith('_')]

    def __len__(self):
        return len(self.keys())

    def __str__(self):
        return '<Values:%s(#%s)>' % (self.path(), len(self))

    def __repr__(self):
        return 'Values(%s)'%self.keys()#+str(dict(values))+')'

    def __init__(self, defaults=None, source_file=None, root=None, source_key=None):
        self.__dict__['parent'] = root
        self.__dict__['initialized'] = False

        if not source_key:
            source_key = self.default_source_key
        self.__dict__['source_key'] = source_key
        if source_file:
            self[source_key] = source_file
            #self.__dict__[self.source_key] = source_file

        self.__dict__['changelog'] = []
        #self.__dict__.update(dict(
        #    parent=root, updated=False, source_file=source_file))
        #print '1', self.__dict__
        if defaults:
            for key in defaults:
                self.initialize(key, defaults[key])
        self.__dict__['initialized'] = True
        #TODO:self.updated = False

    def initialize(self, key, value):
        if isinstance(value, dict):
            self[key] = self.__class__(value, root=self)
        elif isinstance(value, list):
            _list = [i for i in value]
            self[key] = []
            for c in value:
                if isinstance(c, dict):
                    i = self.__class__(c, root=self)
                elif isinstance(c, list):
                    # XXX: hardcoded recursion depth (at 2)
                    i = []
                    for c2 in c:
                        if isinstance(c2, dict):
                            i2 = self.__class__(c2, root=self)
                        elif isinstance(c2, list):
                            raise Exception("list recursion")
                        else:
                            i2 = c2
                        i.append(i2)
                else:
                    i = c
                self[key].append(i)
        else:
            self[key] = value


    def set_source_key(self, key):
        ckey = self.source_key
        if ckey and ckey in self:
            value = self.source
            del self[ckey]
        self.__dict__['source_key'] = key
        if ckey and value:
            self[self.source_key] = value

    @property
    def source_key(self):
        return self.__dict__['source_key']

    @property
    def source(self):
        return self[self.source_key]

    def __getitem__(self, name):
        mod = self
        if '.' in name:
            path = name.split('.')
            while path:
                mod = mod[path.pop(0)]
                if len(path) == 1:
                    name = path.pop(0)
        else:
            return dict.__getitem__(self, name)
        return mod.__getitem__(name)

    def getroot(self):
        mod = self
        while mod.__dict__['parent']:
            mod = mod.__dict__['parent']
        return mod

    def getsource(self):
        mod = self
        if mod.source_key and mod.source_key in mod:
            return mod
        if mod.__dict__['parent']:
            supmod = mod.__dict__['parent']
            return supmod.getsource()

    def append_changelog(self, key):
        if not self.getroot().__dict__['initialized']:
            return
        #print 'append_changelog', self, key, self.source_key
        if key == '.source_key' or key == '.'+self.source_key:
            return
        src = self.getsource()
        if src:
            cl = src.__dict__['changelog']
            if key not in cl:
                cl.append(key)

    def __setitem__(self, name, v):
        mod = self
        if '.' in name: # expand dotted paths
            path = name.split('.')
            while path:
                comp = path.pop(0)
                if comp not in mod:
                    mod[comp] = self.__class__(root=mod)
                mod = mod[comp]
                if len(path) == 1:
                    name = path.pop(0)
        else:
            k = self.path()+'.'+name
            self.append_changelog(k)
            return dict.__setitem__(self, name, v)
        k = self.path()+'.'+name
        self.append_changelog(k)
        return mod.__setitem__(name, v)

    def __setattr__(self, name, v):
        if name in self.__dict__:
            self.__dict__[name] = v
        else:
            return dict.__setitem__(self, name, v)

    def __getattr__(self, name):
        if name in self.__dict__:
            return self.__dict__[name]
        else:
            return dict.__getitem__(self, name)

    def path(self):
        """
        Return a module path for this Values instance.
        """
        pp = ''
        p = self.__dict__['parent'] 
        if p:
            pp = p.path()
            for k in p.keys():
                if p[k] == self:
                    pp += '.' +k
                    break
        return pp

    def override(self, settings):
        for k in dir(settings):
            if k.startswith('_'):
                continue
            v = getattr(settings, k)
            if v:
                self[k] = v

    @property
    def changelog(self):
        return self.__dict__['changelog']

    def todict(self, deep=True):
        if deep:
            return self.copy(True)
        else:
            c = dict()
            assert False

    def copy(self, plain=False):
        """
        Return deep copy dicts 'n lists copy.
        XXX: lists can only nest twice
        TODO: reimplement this as tree visitor
        """
        if plain:
            c = dict()
        else:
            c = self.__class__()
        for k in self:
            if plain and hasattr(self[k], 'todict'):
                c[k] = self[k].todict(True)
            elif hasattr(self[k], 'copy'):
                c[k] = self[k].copy()
            elif hasattr(self[k], 'keys') and not self[k].keys():
                c[k] = dict()
            elif isinstance(self[k], list):
                # XXX: hardcoded list nesting depth (at 2)
                c[k] = []
                for c1 in self[k]:
                    if plain and hasattr(c1, 'todict'):
                        i = c1.todict(True)
                    elif hasattr(c1, 'copy'):
                        i = c1.copy()
                    elif hasattr(c1, 'keys') and not c1.keys():
                        i = dict()
                    elif isinstance(c1, list):
                        i = []
                        for c2 in c1:
                            if plain and hasattr(c2, 'todict'):
                                i2 = c2.todict(True)
                            if hasattr(c2, 'copy'):
                                i2 = c2.copy()
                            elif hasattr(c2, 'keys') and not c2.keys():
                                i2 = dict()
                            elif isinstance(c2, list):
                                raise Exception("list recursion, only two levels")
                            else:
                                i2 = c2
                            i.append(i2)
                    else:
                        i = c1
                    c[k].append(i)

            else:
                c[k] = self[k]
        return c


def backup(file):
    """
    Move existing file to numbered backup location.
    If file is a symlink, its target is moved.
    """
    # Find non-existant path with suffix '~[0-9]*'
    cnt = 0
    psuf = ''
    bup = file+'~'
    while os.path.exists(bup):
        cnt += 1
        if psuf:
            bup = bup[:-len(psuf)] + str(cnt)
        else:
            bup += str(cnt)
        psuf = str(cnt)
    # Copy or move currentfile to suffixed
    #if not re.match('~[0-9]*', file):
    if os.path.islink(file):
        os.rename(os.path.realpath(file), bup)
    else:
        os.rename(file, bup)


class YAMLValues(Values):

    """
    Loads configuration settings from YAML file.
    """
#    def __init__(self, path):
#        ValueStorage.__init__(self, path)

    def commit(self, do_backup=True):
        """
        Save settings in nearest config module.
        """
        print '!!! NO-op: commit', self

        mod = self.getsource()
        #mod.copy(prune_mod=True)
        #mod.commit()

        ##if self.__dict__['parent']:
        #    self.root().commit()
        #else:
        #    print 'saving to',self.source
        #    #assert 'source_key' in self
        #    #file = self[self['source_key']]
        #    file = self.source;#__dict__[self.__dict__['source_key']]
        #    if do_backup:
        #        backup(file)
        #    data = self.copy()
        #    yaml_dump(data, open(file, 'a+'))

    @classmethod
    def load(cls, path):
        try:
            data = yaml_load(open(path).read())
        except Exception, e:
            raise Exception("Parsing %s: %s"%(path, e))
        settings = cls(data, source_file=path, source_key='config_file')
        #if path not in _paths:
        #    _paths[path] = genid
        #    setattr(_, genid, settings)
        return settings

    def reload(self):
        if self.__dict__['parent']:
            raise Exception("Cannot reload node")
        file = self.source
        return load_path(file)

# XXX:
class FSValues(Values):

    @classmethod
    def load(cls, path):
        return
        data = fs_load(open(path).read())
        settings = cls(data, source_file=path)
        return settings



# Main interface

def yaml(path, *args):
    assert not args, "Cannot override from multiple files: %s, %s " % (path, args)
    return load_path(path, type=YAMLValues)

def init_config(name, paths=name_prefixes, default=None):

    """
    Expect one existing config for name, otherwise initialize.

    Note that default must be a complete path that is matched by
    confparse.name_prefixes.
    """

    rcfile = expand_config_path(name, paths=paths)

    if default == '.':
        default += name
    
    if not rcfile:
        assert default, "Not initialized: %s for %s" % (name, paths)
        for path in find_config_path('cllct', paths=paths, suffixes=['','.rc'],
                prefixes=['.',''],exists=lambda x:True):
            print "TODO:", path
        rcfile = os.path.expanduser(default)

    os.path.mknode(rcfile)
    # XXX: redundant op, check paths constraint setting
    assert expand_config_path(name, paths=paths) == rcfile

    return yaml(rcfile)

def load_path(path, values_type=YAMLValues):
    global _paths, _
    assert inspect.isclass(values_type), values_type
    return getattr(values_type, 'load')(path)

def load(name, paths=path_prefixes):
    global _paths, _
    configs = expand_config_path(name, paths=paths)
    try:
        while configs:
            config = configs.next()
            if os.path.exists(config): break
    except StopIteration, e:
        raise Exception("Unable to find config file for", name, paths)
        #sys.exit(1)
    ext = splitext(config)[1]
    if isdir(config):
        assert not ext
        values_type = FSValues 
    else:
        assert not ext or ext == 'yaml', ext
        values_type = YAMLValues
    _paths[config] = name
    settings = load_path(config, type=values_type)
    setattr(_, name, settings)
    return settings


class ValuesFacade(Values):

    default_source_key = 'config_file'
    default_config_key = 'default'

    def __init__(self, *args, **kwds):
        super(ValuesFacade, self).__init__(*args, **kwds)
        self.overrides = []

    @classmethod
    def load(Klass, path, source_key=default_source_key,
            config_key=default_config_key):
        try:
            data = yaml_load(open(path).read())
        except Exception, e:
            raise Exception("Parsing %s: %s"%(path, e))
        config = Klass(data, source_file=path,
                source_key=source_key)
        if 'parent_key' not in config:
            config.parent_key = config_key
        return config

    def add_override(self, other):
        self.overrides.append(other)


def load_all(names, alt_paths=path_prefixes, prefixes=name_prefixes,
        exts=name_suffixes, configtype=YAMLValues):
    "New-style loader. "
    root = ValuesFacade(dict())
    root.parent_key = configtype.default_config_key
    for name in names:
        for path in find_config_path(name, path=getcwd(), paths=alt_paths,
                prefixes=name_prefixes, suffixes=exts):
            loaded = load_path(path, configtype)
            if loaded.parent_key:
                root.add_override(loaded)
    return root

_ = Values()


# XXX: testing
if __name__ == '__main__':
    configs = list(expand_config_path('cllct.rc')) 
    assert configs == ['/Users/berend/.cllct.rc'], configs
