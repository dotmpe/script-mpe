import os, types, syck
from pprint import pformat


config_prefix = (
    '',  # local (cwd) name
    '.', # local hidden name
    '~/.', # hidden name in $HOME
    '/etc/' # name in /etc/
)

def get_config(name, paths=config_prefix):

    """
    Yield all existing config paths. See config_prefix for search path.

    Expands '~/' and '~`username`/' sequences.
    """

    paths = list(paths)

    for prefix in paths:
        path = os.path.expanduser(prefix + name)
        if os.path.exists(path):
            yield path


class Values(dict):
    
    def __init__(self, defaults=None):
        if defaults:
            for key in defaults:
                if isinstance(defaults[key], dict):
                    self[key] = Values(defaults[key])
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

    def __getattr__(self, name):
        return dict.__getitem__(self, name)

    def override(self, settings):
        for k in dir(settings):
            if k.startswith('_'):
                continue
            v = getattr(settings, k)
            if v:
                self[k] = v


def yaml(path, *args):
    assert not args, "Cannot override from multiple files "
    data = syck.load(open(path).read())
    return Values(data)


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

    cllct_runcom = get_config('cllct.rc').next()
    print 'cllct.rc', cllct_runcom

    #cllct_settings = ini(cllct_runcom) # old ConfigParser based, see confparse experiments.
    cllct_settings = yaml(cllct_runcom)

    print 'cllct_settings', pformat(cllct_settings)

    print cllct_settings.cllct.test


