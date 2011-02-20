import os, types, syck
from pprint import pformat


config_paths = (
    [], 
    ['~', '.'],
    ['/etc/', ]
)


def get_config(name):

    """
    Yield all existing config paths. See config_paths.
    """

    paths = list(config_paths)

    for dir in paths:
        if dir and dir[-1] == '.':
            dir[-1] += name
        else:
            dir.append(name)
        path = os.path.expanduser(os.path.join(*dir))
        if os.path.exists(path):
            yield path


class Values(dict):
    
    def __init__(self, defaults):
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


def yaml(path): 
    data = syck.load(open(path).read())
    return Values(data)


if __name__ == '__main__':

    cllct_runcom = get_config('cllct.rc').next()
    print 'cllct.rc', cllct_runcom

    #cllct_settings = ini(cllct_runcom) # old ConfigParser based, see confparse experiments.
    cllct_settings = yaml(cllct_runcom)

    print 'cllct_settings', pformat(cllct_settings)

    print cllct_settings.cllct.test


