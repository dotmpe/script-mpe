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
import re
from script_mpe import log, confparse
from urlparse import urlparse

from . import js
from .dt import iso8601_from_stamp
from .. import lib
from ..taxus.model import Bookmark
from ..taxus.core import Tag, Name
from ..taxus.net import Locator, Domain



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

_ttuple = lambda text, attrs: tuple(( text, attrs ))

def nextSibling(soup):
    if not soup.nextSibling:
        return
    soup = soup.nextSibling
    while not str(soup).strip():
        soup = soup.nextSibling
    return soup

class TxtBmOutline(object):

    """
    Helper for printing bookmark outlines in various formats.
    """

    @classmethod
    def from_beautifulsoup(klass, s, output_format, print_leafs=True):
        return '\n'.join( [ '- '+s.title.text, '', ] +
                TxtBmOutline.bm_html_soup_format_dl(s, output_format, print_leafs ) )

    format = dict( folder={
      'tree': lambda dl,i: (i*'  ')+dl.h3.text,
      'txt': lambda dl,i: (i*'  ')+dl.h3.text,
      'rst': lambda dl,i: (i*'  ')+dl.h3.text,
      'list.txt': lambda dl,i:
        (i*':')+' '+(':' in dl.h3.text and dl.h3.text or dl.h3.text+':')+\
                ' lm:'+dl.h3['last_modified']+\
                ' ad:'+dl.h3['add_date']
    }, leaf={
      'tree': lambda dt,i: (i*'  ')+dt.a.text,
      'txt': lambda dt,i: (i*'  ')+'- '+dt.a.text+' <'+dt.a['href']+'>'+
                ( dt.a.get('add_date') and ' '+iso8601_from_stamp(dt.a['add_date']) or '' ),
      'rst': lambda dt,i: (i*'  ')+'- `'+dt.a.text+' <'+dt.a['href']+'>`_',
      'list.txt': lambda dt,i:
          (i*':')+' '+(':' in dt.a.text and dt.a.text or dt.a.text+':')+' <'+dt.a['href']+'>'
    })

    @classmethod
    def format_folder_item(klass, dl, i, **kwds):
        return klass.format['folder'][kwds['output_format']](dl, i)

    @classmethod
    def format_leaf_item(klass, dt, i, **kwds):
        return klass.format['leaf'][kwds['output_format']](dt, i)

    @classmethod
    def bm_html_soup_dlitem_gen(klass, dl, i=1, **kwds):
        """
        Generate lines in requested format for outline tree found in Soup
        element dl.
        """
        if not dl:
            return
        of = kwds['output_format']
        if dl.h3:
            #if of == 'rst':
            #    yield ''
            yield klass.format_folder_item(dl, i, **kwds)
        elif dl.a:
            if kwds['print_leafs']:
                yield klass.format_leaf_item(dl, i, **kwds)

        # Recurse
        sub = dl.find('dl', recursive=False)
        if sub:
            terms = sub.findAll('dt', recursive=False)
            for dt in terms:
                sl = klass.bm_html_soup_dlitem_gen(dt, i+1, **kwds)
                for l in sl:
                    yield l
            #if terms:
            #    if of == 'rst':
            #        yield ''

    @classmethod
    def bm_html_soup_format_dl(klass, s, output_format, print_leafs):
        """Format a plain-text nested list from BeautifulSoup. Returns list of
        lines. """
        subs = s.findAll('dl', recursive=False)
        ls = []
        if subs:
            for sub in subs:
                g = klass.bm_html_soup_dlitem_gen(sub, 1,
                        output_format=output_format, print_leafs=print_leafs)
                if g:
                    ls.extend( list(g) )
        return ls

    @classmethod
    def bm_html_soup_items_gen(klass, s, folder_class=_ttuple,
            item_class=_ttuple):
        lists = s.findAll('dl', recursive=False)
        if not lists:
            return
        for dl in lists:
            return klass.bm_html_soup_dlitems_gen(dl, folder_class=folder_class,
                    item_class=item_class)

    @classmethod
    def bm_html_soup_dlitems_gen(klass, dl, folder_class=_ttuple,
            item_class=_ttuple, stack=[]):
        assert dl.name == 'dl', dl
        terms = dl.findAll('dt', recursive=False)
        for term in terms:
            if term.find('h3', recursive=False):
                attrs = term.h3._getAttrMap()
                if stack:
                    attrs['parent'] = stack[-1]
                stack.append(folder_class(term.h3.text, attrs))
                yield stack[-1]
                subdl = nextSibling(term.h3)
                if subdl:
                    for it in klass.bm_html_soup_dlitems_gen(subdl,
                            folder_class=folder_class, item_class=item_class,
                            stack=stack):
                        yield it
                stack.pop()

            elif term.a:
                attrs = term.a._getAttrMap()
                if stack:
                    attrs['parent'] = stack[-1]
                yield item_class(term.a.text, attrs)

        return



# Formatters for BeautifulSoup fragments of bookmarks.html

html_soup_formatters = {
        #'json': lambda s: s,
        'tree': lambda s: TxtBmOutline.from_beautifulsoup(s, 'tree'),
        'txt': lambda s: TxtBmOutline.from_beautifulsoup(s, 'txt'),
        'rst': lambda s: TxtBmOutline.from_beautifulsoup(s, 'rst'),
        'list.txt': lambda s: TxtBmOutline.from_beautifulsoup(s, 'list.txt')
    }



###

class BmImporter(object):

    def __init__(self, sa):
        self.sa = sa
        self.r = 0
        self.tags_stat = {}
        self.domains_stat = {}

    def flush(self, g):
        if not g.dry_run:
            self.sa.commit()

    def batch_flush(self, g):
        """Commit every x records"""
        if not g.dry_run:
            if g.auto_commit and self.r and self.r % g.auto_commit == 0:
                self.sa.commit()

    def init_locator(self, href, date_added):
        if not self.prep_domain(href):
            return

        # get/init Locator
        lctr = Locator.fetch((Locator.ref == href,), exists=False)
        if lctr:
            if date_added and lctr.date_added > date_added:
                lctr.date_added = date_added
                log.std("updated: %s", lctr)
                self.sa.add(lctr) ; self.r+=1
        else:
            lctr = Locator( ref=href, date_added=date_added )
            lctr.init_defaults()
            log.std("new: %s", lctr)
            self.sa.add(lctr) ; self.r+=1

        return lctr

    def init_bookmark(self, locator, date_added, name, extended, tagcsv):
        # get/init Bookmark
        bm = Bookmark.fetch((Bookmark.location == locator,), exists=False)
        if bm:
            if bm.date_added != date_added:
                bm.date_added = date_added
                self.sa.add(bm) ; self.r+=1
            if bm.location != locator:
                bm.ref = locator
                self.sa.add(bm) ; self.r+=1
        else:
            bm = Bookmark.fetch((Bookmark.name == name,), exists=False)
            if bm:
                log.std("Name already exists: %r" % name)
                return
            bm = Bookmark(
                    location=locator,
                    name=name,
                    extended=extended,
                    tags=tagcsv,
                    date_added=date_added
                )
            bm.init_defaults()
            log.std("new: %s", bm)
            self.sa.add(bm) ; self.r+=1

        # track tag frequency
        if tagcsv:
            self.prep_tags(tagcsv)

        return bm

    def prep_domain(self, href):
        # validate Locator
        url = urlparse(href)
        domain = url[1]
        if not domain:
            log.std("Ignored domainless (non-net?) URIRef: %s", href)
            return
        assert re.match('[a-z0-9]+(\.[a-z0-9]+)*', domain), domain
        # track domain frequency
        if domain in self.domains_stat:
            self.domains_stat[domain] += 1
        else:
            self.domains_stat[domain] = 1
        return url

    def get_domain_offset(self, g):
        domain_offset = int(g.domain_offset)
        if domain_offset > 0:
            return domain_offset
        # Prepare domain stats
        avgDomainFreq = sum(self.domains_stat.values())/(len(self.domains_stat)*1.0)
        hiDomainFreq = max(self.domains_stat.values())
        log.std("Found domain usage (max/avg): %i/%i", hiDomainFreq, avgDomainFreq)
        if domain_offset == 0:
            domain_offset = hiFreq
        elif domain_offset == -1:
            domain_offset = round(hiDomainFreq * 0.2)
        log.std("Setting domain-offset: %i", domain_offset)
        return domain_offset

    def flush_domains(self, g):
        domains = 0
        domain_offset = self.get_domain_offset(g)
        for domain in self.domains_stat:
            freq = self.domains_stat[domain]
            if freq >= domain_offset:
                domains += 1
                domain_record = Domain.fetch((Domain.name == domain,), exists=False)
                if not domain_record:
                    assert domain, domain
                    domain_record = Domain(name=domain)
                    domain_record.init_defaults()
                    self.sa.add(domain_record) ; self.r+=1
            # commit every x records
            self.batch_flush(g)
        log.std("Checked %i domains", len(self.domains_stat))
        log.std("Tracking %i domains", domains)
        self.flush(g)

    def prep_tags(self, tagcsv):
        # track tag frequency
        for tag in tagcsv.split(', '):
            if tag in self.tags_stat:
                self.tags_stat[tag] += 1
            else:
                self.tags_stat[tag] = 1

    def get_tag_offset(self, g):
        tag_offset = int(g.tag_offset)
        if tag_offset > 0:
            return tag_offset
        # Prepare tag stats
        avgFreq = sum(self.tags_stat.values())/(len(self.tags_stat)*1.0)
        hiFreq = max(self.tags_stat.values())
        log.std("Found tag usage (max/avg): %i/%i", hiFreq, avgFreq)
        if tag_offset == 0:
            tag_offset = hiFreq
        elif tag_offset == -1:
            tag_offset = round(hiFreq * 0.1)
        log.std("Setting tag-offset: %i", tag_offset)
        return tag_offset

    def flush_tags(self, g):
        tag_offset = self.get_tag_offset(g)
        # get/init Tags
        tags = 0
        for tag in self.tags_stat:
            freq = self.tags_stat[tag]
            if freq >= tag_offset:
                # Store tags only if count exceeds offset
                tags += 1
                tag_id = lib.tag_id(tag)
                if not tag.strip() or not tag_id:
                    log.std("Empty tag: %r <%s> (%s)", tag, tag_id, freq)
                    continue
                t = Tag.fetch((Tag.tag == tag_id,), exists=False)
                if t:
                    continue
                n = Name.fetch((Name.name == tag,), exists=False)
                if n:
                    continue
                t = Tag(name=tag, tag=tag_id)
                if not t.tag:
                    log.std("empty tag %r for name %r", t.tag, tag)
                else:
                    t.init_defaults()
                    log.std("new tag %r for %r", t, tag)
                    self.sa.add(t) ; self.r+=1
                # store frequencies
                # TODO tags_freq
            # commit every x records
            self.batch_flush(g)
        log.std("Checked %i tags", len(self.tags_stat))
        log.std("Tracking %i tags", tags)
        self.flush(g)
