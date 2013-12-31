import log
import res.js



class MozJSONExport(object):

    def __init__(self):
        super(MozJSONExport, self).__init__()
        self.reset()

    def reset(self):
        self.bookmarks = {}
        self.groups = {}

    def init(self, path):
        log.info("reading %s", path)
        data = open(path).read()
        self.json = res.js.loads(data)

    def read_bm(self, path):
        self.init(path)

        def recurse(js, lvl=0):
            if 'id' in js and js['id']:
                if js['id'] == 1912:
                    import sys
                    sys.exit()
            #    print
            #    print ( '\t'*lvl ) + str(json['id'])
            #if 'title' in json and json['title']:
            #    print ( '\t'*lvl ) + json['title']
            if 'uri' in js and js['uri']:
                yield js#['uri']
                #print ( '\t'*lvl ) + json['uri']
            if 'children' in js:
                for x in js['children']:
                    for y in recurse(x, lvl+1):
                        yield y

        for node in recurse(self.json):

            if 'uri' in node:
                ref = node['uri']
            if ref.startswith('place:'): # mozilla things
                continue
            elif ref.startswith('chrome:') or ref.startswith('about:') \
                or ref.startswith('file:') \
                or ref.startswith('javascript:') \
                or ref.startswith('http:') or ref.startswith('https:'):
                yield ref
            else:
                assert False, ref


