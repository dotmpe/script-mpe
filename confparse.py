"""confparse - persisted metadata

This module stores and loads configuration settings. Once loaded,
confparse._.name provides access to the structure from storage (see Values)
Structure may consist of dictionaries, lists and primitive values.

get_config(leafname)
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
"""
import os, re, sys, types
from os import unlink, removedirs, makedirs, tmpnam, chdir, getcwd
from os.path import join, dirname, exists, isdir, realpath
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

config_prefix = (
    '',  # local (cwd) name
    '.', # local hidden name
)

config_path = (
    '~/.', # hidden name in $HOME
    '/etc/' # name in /etc/
)

config_suffix = (
    '',
    '.yaml',
    '.conf',
)


def expand_config_path(name, paths=config_prefix):

    """
    Yield all existing config paths. See config_prefix for search path.

    Expands '~/' and '~`username`/' sequences.
    """

    return find_config_path(name, path=getcwd(), paths=list(paths))

def tree_paths(path):
    parts = path.strip(os.sep).split(os.sep)
    while parts:
        cpath = os.path.join(*parts)
        if path.startswith(os.sep):
            cpath = os.sep+cpath
        yield cpath
        parts.pop()
        #parts = parts[:-1]

def find_config_path(markerleaf, path=None, prefixes=config_prefix,
        suffixes=config_suffix, paths=[]):
    """
    Search paths for markerleaf with prefixes/suffixes.
    """
    if path:
    	paths.extend(tree_paths(path))
    for cpath in paths:
        for prefix in prefixes:
            for suffix in suffixes:
            	cleaf = markerleaf
                if not markerleaf.startswith(prefix):
                	cleaf = prefix + markerleaf
                if not markerleaf.endswith(suffix):
                	cleaf += suffix
                cleaf = os.path.join(cpath, cleaf)
                if os.path.exists(cleaf):
                    yield cleaf


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

class ValueStorage:
    def __init__(self, path):
        self.path = path


class YAMLStorage(ValueStorage):
    def __init__(self, path):
        ValueStorage.__init__(self, path)

class Values(dict):

    def __str__(self):
        return '<Values>'

    def __repr__(self):
        return 'Values(%s)'%self.keys()#+str(dict(values))+')'

    def __init__(self, defaults=None, file=None, root=None, source_key=None):
        self.__dict__['parent'] = root
        #self.updated = False
        if not source_key:
            source_key = 'file'
        self.__dict__['source_key'] = source_key
        if file:
            self[source_key] = file
            #self.__dict__[self.source_key] = file
        #self.__dict__.update(dict(
        #    parent=root, updated=False, file=file))
        #print '1', self.__dict__
        if defaults:
            for key in defaults:
                self.initialize(key, defaults[key])

    def initialize(self, key, value):
        if isinstance(value, dict):
            self[key] = Values(value, root=self)
        elif isinstance(value, list):
            _list = [i for i in value]
            self[key] = []
            for c in value:
                if isinstance(c, dict):
                    i = Values(c, root=self)
                elif isinstance(c, list):
                    # XXX: hardcoded recursion depth (at 2)
                    i = []
                    for c2 in c:
                        if isinstance(c2, dict):
                            i2 = Values(c2, root=self)
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

    def __setitem__(self, name, v):
        #self.getroot().updated = True
        mod = self
        if '.' in name: # expand dotted paths
            path = name.split('.')
            while path:
                comp = path.pop(0)
                if comp not in mod:
                    mod[comp] = Values(root=mod)
                mod = mod[comp]
                if len(path) == 1:
                    name = path.pop(0)
        else:
            return dict.__setitem__(self, name, v)
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

    def override(self, settings):
        for k in dir(settings):
            if k.startswith('_'):
                continue
            v = getattr(settings, k)
            if v:
                self[k] = v

    def commit(self):
        print self.changelog

        #if self.__dict__['parent']:
        #    self.root().commit()
        #else:
        #    #assert 'source_key' in self
        #    #file = self[self['source_key']]
        #    file = self.source;#__dict__[self.__dict__['source_key']]
        #    backup(file)
        #    data = self.copy()
        #    yaml_dump(data, open(file, 'a+'))

    def copy(self):
        """
        Return flat dicts 'n lists copy.
        """
        c = dict()
        for k in self:
            if hasattr(self[k], 'copy'):
                c[k] = self[k].copy()
            elif hasattr(self[k], 'keys') and not self[k].keys():
                c[k] = dict()
            elif isinstance(self[k], list):
                # XXX: hardcoded recursion depth (at 2)
                c[k] = []
                for c1 in self[k]:
                    if hasattr(c1, 'copy'):
                        i = c1.copy()
                    elif hasattr(c1, 'keys') and not c1.keys():
                        i = dict()
                    elif isinstance(c1, list):
                        i = []
                        for c2 in c1:
                            if hasattr(c2, 'copy'):
                                i2 = c2.copy()
                            elif hasattr(c2, 'keys') and not c2.keys():
                                i2 = dict()
                            elif isinstance(c2, list):
                                raise Exception("list recursion")
                            else:
                                i2 = c2
                            i.append(i2)
                    else:
                        i = c1
                    c[k].append(i)

            else:
                c[k] = self[k]
        return c

    def reload(self):
        if self.__dict__['parent']:
            raise Exception("Cannot reload node")
        file = self.source
        return yaml(file)


def yaml(path, *args):
    assert not args, "Cannot override from multiple files: %s, %s " % (path, args)
    data = yaml_load(open(path).read())
    return Values(data, file=path)


def init_config(name, paths=config_prefix, default=None):

    """
    Expect one existing config for name, otherwise initialize.

    Note that default must be a complete path that is matched by
    confparse.config_prefix.
    """

    rcfile = get_config(name, paths=paths)

    if not rcfile:
        assert default, "Not initialized: %s for %s" % (name, paths)
        rcfile = os.path.expanduser(default)

    os.path.mknode(rcfile)
    # XXX: redundant op, check paths constraint setting
    assert get_config(name, paths=paths) == rcfile

    return yaml(rcfile)

# Main interface

def load_file(path, type=None):
    global _paths, _
    settings = yaml(path)
    #settings = Values(data, file=path)
    #if path not in _paths:
    #	_paths[path] = genid
    #	setattr(_, genid, settings)
    return settings

def load(name, paths=config_prefix):
    global _
    configs = expand_config_path(name, paths=paths)
    config = configs.next()
    _paths[config] = name
    settings = load_file(config)
    setattr(_, name, settings)
    return settings

_ = Values()

# Testing

def test1():
    #cllct_settings = ini(cllct_runcom) # old ConfigParser based, see confparse experiments.
    test_settings = yaml(test_runcom)

    print 'test_settings', pformat(test_settings)

    if 'foo' in test_settings and test_settings.foo == 'bar':
        test_settings.foo = 'baz'
    else:
        test_settings.foo = 'bar'

    test_settings.path = Values(root=test_settings)
    test_settings.path.to = Values(root=test_settings.path)
    test_settings.path.to.some = Values(root=test_settings.path.to)
    test_settings.path.to.some.leaf = 1
    test_settings.path.to.some.str = 'ABC'
    test_settings.path.to.some.tuple = (1,2,3,)
    test_settings.path.to.some.list = [1,2,3,]
    test_settings.commit()

    print 'test_settings', pformat(test_settings)

if __name__ == '__main__':
	test1()


