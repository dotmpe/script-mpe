"""
For use with lind

- Various existing category trees, see:

  - ~/htdocs/Directory.rst



"""
import re


FS_Path_split = re.compile('[\/\.\+,]+').split


class FSFolderLayout(object):

    def __init__(self, name=None, parent=None):
        super(FSFolderLayout, self).__init__()
        self.subs = {}
        self.name = name
#        if name:
#            assert parent
#            parent.subs[name] = self

    @property
    def is_root(self):
        return self.name == None

    def __iter__(self):
        return iter(self.subs.items())

    def add_rule(self, rule):
        assert isinstance(rule, basestring)
        path = FS_Path_split(rule)
        while path:
            root = path.pop(0)
            if not root:
                continue
            if root in self.subs:
                fl = self.subs[root]
            else:
                fl = FSFolderLayout(root)
                self.subs[root] = fl
            fl.add_rule('/'.join(path))
            return fl

    def __repr__(self, i=0):
        pad = '  ' * i
        subs = ''
        i+=1
        for k, s in self.subs.items():
            subs += s.__repr__(i=i)
        if self.name:
            return "%s%s/\n  %s" % (pad, self.name, subs)
        else:
            return "%s (root):\n  %s" % (pad, subs)


