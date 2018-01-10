"""
Code for dealing with bookmark file formats.

Mozilla JSON export
    ..

bookmarks.html (BeautifulSoup)
    This SGML outline format for bookmark menus made with DL/DT and A's
    and H3's is still the backup/import/export format supported by major browsers.

Issues
    rSt format does not print dl but nested list
"""
from script_mpe import log, confparse

import js



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

    def read_lctr(self, path):
        for node in self.read_bm(path):
            yield node['uri']

    def read_bm(self, path):
        for node in self.read(path):
            if 'children' in node:
                continue
            if 'uri' in node:
                ref = node['uri']
            if ref.startswith('place:'): # mozilla things
                continue
            elif ref.startswith('chrome:') or ref.startswith('about:') \
                or ref.startswith('file:') \
                or ref.startswith('javascript:') \
                or ref.startswith('http:') or ref.startswith('https:'):
                yield node
            else:
                assert False, node

    def read(self, path):
        self.init(path)
        def recurse(js, lvl=0):
            #if 'id' in js and js['id']:
            #    if js['id'] == 1912:
            #        import sys
            #        sys.exit()
            #    print
            #    print ( '\t'*lvl ) + str(json['id'])
            #if 'title' in json and json['title']:
            #    print ( '\t'*lvl ) + json['title']
            if 'uri' in js and js['uri']:
                assert 'children' not in js, "what to do %s" % js
                yield js#['uri']
                #print ( '\t'*lvl ) + json['uri']
            elif 'children' in js:
                yield js
                for x in js['children']:
                    for y in recurse(x, lvl+1):
                        yield y
            elif 'parent' in js or 'root' in js or 'title' in js:
                yield js
            else:
                log.warn("Ignored node %s", js)
        for node in recurse(self.json):
            yield node



def rst_print(bm, i=1):
    """
    Print MozJSONExport as a rSt-reminiscent nested list
    """
    print i*'  ', '-', '`'+bm.name + ('url' in bm and ' <'+bm.url+'>`_' or '`')
    if 'children' in bm and bm.children:
        print
        for sb in bm.children:
            rst_print(confparse.Values(sb), i+1)
        print

moz_json_printer = dict(
    item={
        'rst': lambda group: rst_print(group),
        'json': lambda group: js.dump(group),
        'outline': lambda group: rst_print(group)
    })


class TxtBmOutline(object):

    """
    Helper for printing bookmark outlines in various formats.
    """

    @classmethod
    def from_beautifulsoup(klass, s, output_format, print_leafs=True):
        return '\n'.join( [ '- '+s.title.text, '', ] +
                TxtBmOutline.bm_html_soup_dl(s, output_format, print_leafs ) )

    format = dict( folder={
      'tree': lambda dl,i: (i*'  ')+dl.h3.text,
      'rst': lambda dl,i: (i*'  ')+'- `'+dl.h3.text+'`',
      'list.txt': lambda dl,i:
        (i*':')+' '+(':' in dl.h3.text and dl.h3.text or dl.h3.text+':')+' ad:'+\
                  dl.h3['add_date']+' lm:'+dl.h3['last_modified']
    }, leaf={
        'tree': lambda dl,i: (i*'  ')+dl.a.text,
        'rst': lambda dl,i: (i*'  ')+'- `'+dl.a.text+': <'+dl.a['href']+'>`_',
        'list.txt': lambda dl,i:
            (i*':')+' '+(':' in dl.a.text and dl.a.text or dl.a.text+':')+' <'+dl.a['href']+'>'
    })

    @classmethod
    def format_folder_item(klass, dl, i, **kwds):
        return klass.format['folder'][kwds['output_format']](dl,i)

    @classmethod
    def format_leaf_item(klass, dl, i, **kwds):
        return klass.format['leaf'][kwds['output_format']](dl,i)

    @classmethod
    def bm_html_soup_item_gen(klass, dl, i=1, **kwds):
        """
        Generate lines in requested format for outline tree found in Soup
        element dl.
        """
        if not dl:
            return
        of = kwds['output_format']
        if dl.h3:
            yield klass.format_folder_item(dl, i, **kwds)
        elif dl.a:
            if kwds['print_leafs']:
                yield klass.format_leaf_item(dl, i, **kwds)
        sub = dl.find('dl', recursive=False)
        if sub:
            terms = sub.findAll('dt', recursive=False)
            if terms:
                if of == 'rst':
                    yield ''
            for dt in terms:
                sl = klass.bm_html_soup_item_gen(dt, i+1, **kwds)
                for l in sl:
                    yield l
            if terms:
                if of == 'rst':
                    yield ''

    @classmethod
    def bm_html_soup_dl(klass, s, output_format, print_leafs):
        """Fromat an plain-text nested list from BeautifulSoup. Returns list of
        lines. """
        subs = s.find('dl', recursive=False)
        ls = []
        if subs:
            for sub in subs:
                g = klass.bm_html_soup_item_gen(sub, 1,
                        output_format=output_format, print_leafs=print_leafs)
                if g:
                    ls.extend( list(g) )
        return ls




# Formatters for BeautifulSoup fragments of bookmarks.html

html_soup_formatters = {
        'json': lambda s: s,
        'tree': lambda s: TxtBmOutline.from_beautifulsoup(s, 'tree'),
        'rst': lambda s: TxtBmOutline.from_beautifulsoup(s, 'rst'),
        'list.txt': lambda s: TxtBmOutline.from_beautifulsoup(s, 'list.txt')
    }

