import os
from ... import confparse, res


def full_path(label, generator):
    for sub_label, sub_generator in generator:
        yield list(full_path( " / ".join(( label, sub_label )), sub_generator))
    yield label

def flatten_norecurse(lists):
    index = 0
    while index < len(lists):
         if isinstance(lists[index], list):
             lists[index:index+1] = lists[index]
         else: index += 1
    return lists

class BookmarksJSON:

    """
    Helper to pick (Chrome) Bookmarks JSON.
    """

    def __init__(self, data):
        self.data = data

    def roots(self):
        for k, v in self.data['roots'].items():
            if 'type' in v and v['type'] == 'folder':
                yield k, v

    def merge_roots(self):
        d = dict(children=[], name='root')
        for root, items in self.roots():
            d['children'].extend(items['children'])
        return d

    def urls_gen(self, pick=None, data=None):
        if not data: data = self.merge_roots()
        for v in data['children']:
            if not isinstance(v, dict): continue
            if 'type' in v and v['type'] == 'folder':
                for groups, u in self.urls_gen(pick, v):
                    groups.insert(0, data['name'] )
                    yield groups, u
            elif 'type' in v and v['type'] == 'url':
                if pick:
                    yield [ data['name'] ], v[pick]
                else:
                    yield [ data['name'] ], v

    def groups_gen(self, pick=None, data=None):
        """Yield groups, with a generator for sub-groups.
        If specified, pick attribute to yield iso. group object.
        """
        if not data: data = self.merge_roots()
        for v in data['children']:
            if not isinstance(v, dict): continue
            if 'type' in v and v['type'] == 'folder':
                if pick:
                    yield v[pick], self.groups_gen(pick, v)
                else:
                    yield v, self.groups_gen(pick, v)

    def groups(self, data=None):
        """Yield nested lists of group paths"""
        if not data:
            data = dict(self.roots())
        for k, v in data.items():
            yield list(full_path( k, self.groups_gen('name', v)))

    @staticmethod
    def load(json_file):
        data = res.js.load(open(os.path.expanduser(json_file)))
        return BookmarksJSON(data)

#
