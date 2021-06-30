import os, datetime
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
        for root in self.data['roots']:
            self._convert_microseconds(self.data['roots'][root])

    def roots(self):
        for k, v in self.data['roots'].items():
            if 'type' in v and v['type'] == 'folder':
                yield k, v

    def merge_roots(self):
        """
        Merge all root folders into one and return.
        """
        d = dict(children=[], name='root')
        for root, items in self.roots():
            d['children'].extend(items['children'])
        return d

    def urls_gen(self, pick=None, data=None):
        """
        Recursively yield (group, item) or pick key from item.
        """
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
        """
        Yield groups, with a generator for sub-groups.
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

    def _convert_microseconds(self, data=None):
        if not data: data = self.data['roots']['other']
        for dtk in 'date_added', 'date_modified':
            if dtk in data:
                ts = microseconds_to_timestamp(int(data[dtk]))
                data[dtk] = ts
            else:
                data[dtk] = None
        if 'children' in data:
            for child in data['children']:
                self._convert_microseconds(child)

    @staticmethod
    def load(json_file):
        data = res.js.load(open(os.path.expanduser(json_file)))
        return BookmarksJSON(data)


def microseconds_to_timestamp(i):
    #microseconds = int(dt, 16) / 10
    seconds, microseconds = divmod(i, 1000000)
    days, seconds = divmod(seconds, 86400)
    return datetime.datetime(1601, 1, 1) + datetime.timedelta(days, seconds, microseconds)

#
