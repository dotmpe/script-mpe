from glob import glob
import os

import res
import metafile 
import fs
import session


def dirscan(globp):
    "Return function that given a dir scans for a subpath using a name or pattern. "
    def _scan(path):
        g = os.path.join(path, globp)
        for p in glob(g):
            yield p
    return _scan


class Session(object):

    """

    Knows three kinds of context, each a Workspace which is a specification of
    Metadir. Two of them are special, the Homedir and Volume are two specific
    Workspaces.
    """

    def __init__(self, path):
        self.path = path

    @classmethod
    def init(Class, path, kind):
        self = Class(path)
        self.user = res.Homedir.fetch(path)
        self.volume = res.Volume.fetch(path)
        self.workspace = res.Workspace.fetch(path)
        if kind == 'default':
            self.context = self.workspace or self.volume or self.user
        else:
            self.context = getattr(self, kind)
        self.kind = kind
        return self


