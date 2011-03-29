import os, sys, types
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

config_prefix = (
    '',  # local (cwd) name
    '.', # local hidden name
    '~/.', # hidden name in $HOME
    '/etc/' # name in /etc/
)
            
def backup(file):
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
    os.rename(file, bup)

def get_config(name, paths=config_prefix):

    """
    Yield all existing config paths. See config_prefix for search path.

    Expands '~/' and '~`username`/' sequences.
    """

    paths = list(paths)

    found = []
    for prefix in paths:
        path = os.path.expanduser(prefix + name)
        if os.path.exists(path):
            if not os.path.realpath(path) in found:
                yield path
                found.append(os.path.realpath(path))

def find_parent(markerleaf, path):
    parts = os.path.split(path.strip(os.sep))
    while parts:
        cpath = os.path.join(*parts)
        if path.startswith(os.sep):
            cpath = os.sep+cpath
        for prefix in ('', '.'):
            cleaf = os.path.join(cpath, prefix+markerleaf)
            if os.path.exists(cleaf):
                return cleaf
        parts = parts[:-1]

class Values(dict):

    def __str__(self):
        return '<Values>'
   
    def __repr__(self):
        return 'Values(%s)'%self.keys()#+str(dict(values))+')'
   
    def __init__(self, defaults=None, file=None, root=None):
        self.__dict__['parent'] = root
        #self.updated = False
        if file:
            self.__dict__['file'] = file
        #self.__dict__.update(dict(
        #    parent=root, updated=False, file=file))
        #print '1', self.__dict__
        if defaults:
            for key in defaults:
                if isinstance(defaults[key], dict):
                    self[key] = Values(defaults[key], root=self)
                else:
                    self[key] = defaults[key]

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
        if '.' in name:
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
        if self.__dict__['parent']:
            self.root().commit()
        else:
            file = self.__dict__['file']
            backup(file)
            data = self.copy()
            yaml_dump(data, open(file, 'a+'))

    def copy(self):
        c = dict()
        for k in self:
            if hasattr(self[k], 'copy'):
                c[k] = self[k].copy()
            elif hasattr(self[k], 'keys') and not self[k].keys():
                c[k] = dict()
            else:
                c[k] = self[k]
        return c

    def reload(self):
        if self.__dict__['parent']:
            raise Exception("Cannot reload node")
        file = self.__dict__['file']
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


if __name__ == '__main__':

    print list(get_config('testrc'))
    test_runcom = '.testrc'
    test_runcom = get_config('testrc').next()
    print 'testrc', test_runcom

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



