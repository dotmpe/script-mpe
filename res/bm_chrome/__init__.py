#chrome_bookmarks_path= '~/Library/Application Support/Google/Chrome/Default/Bookmarks'

from ... import confparse, res
#js import load as load_json


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

    def __init__(self, data):
        self.data = data

    def roots(self):
        for k, v in self.data['roots'].items():
            if 'type' in v and v['type'] == 'folder':
                yield k, v

    def groups_gen(self, pick=None, data=None):
        """Yield groups, with a generator for sub-groups.
        If specified, pick attribute to yield iso. group object.
        """
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
        data = res.js.load(open(json_file))
        return BookmarksJSON(data)

