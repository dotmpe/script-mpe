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
from datetime import datetime
from script_mpe import log, confparse
from urllib.parse import urlparse

from . import js
from .dt import parse_chrome_microsecondstamp, iso8601_from_stamp
from script_mpe import lib
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



def rst_print(bm, l=0):
    """
    Print MozJSONExport as a rSt-reminiscent nested list
    """
    print(" ".join((
            l*'  ', '-',
            str(bm.date_added),
            bm.date_modified and str(bm.date_modified) or '-',
            '`'+bm.name + ('url' in bm and ' <'+bm.url+'>`_' or '`')
        )))
    if 'children' in bm and bm.children: # type==folder
        print()
        for sb in bm.children:
            rst_print(confparse.Values(sb), l+1)
        print()


def repr_print(bm, l=0):
    if 'children' in bm and bm.children: # type==folder
        for sb in bm.children:
            repr_print(confparse.Values(sb), l+1)
    elif bm.type == 'url':
        print(repr(bm.todict()))


def outline_print(bm, l=0, groups=[]):
    """
    Print URLs JSON folder outline only.
    """
    if 'children' in bm and bm.children: # type==folder
        print("".join('  '*l, bm.name))
        for sb in bm.children:
            outline_print(confparse.Values(sb), l+1)

tag_re = re.compile('^[A-Za-z0-9\/:\._-]+$')

def todotxt_print(bm, l=0, groups=[]):
    """
    Print URLs as todo.txt formatted lines.
    """
    if bm.type == 'url':
        # Remove windows-epoch timestamps
        print \
            (bm.date_added == u'11644473600000000' and '-' or \
                parse_chrome_microsecondstamp(int(bm.date_added)).isoformat()) \
            + ' '+bm.name \
            + ('url' in bm and ' <'+bm.url+'>' or '') \
            + ('guid' in bm and ' #'+bm.guid+'' or '') \
            + ' '+(
                ' '.join(map(lambda x: '`%s`'%x, filter(lambda s: not
                        tag_re.match(s), groups)))+
                ' '+
                ' '.join(map(lambda x: '@'+x, filter(tag_re.match, groups)))
            )
    elif 'children' in bm and bm.children:
        groups.append(bm.name)
        for sb in bm.children:
            todotxt_print(confparse.Values(sb), l, list(groups))


moz_json_printer = dict(
    item={
        'repr': lambda group: repr_print(group),
        'rst': lambda group: rst_print(group),
        'json': lambda group: js.dump(group),
        'outline': lambda group: outline_print(group),
        'todotxt': lambda group: todotxt_print(group),
        'todo.txt': lambda group: todotxt_print(group)
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
                TxtBmOutline.bm_html_soup_dl_fmt(s, output_format, print_leafs ) )

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
    def bm_html_soup_item_fmt(klass, dl, i=1, **kwds):
        """
        Generate lines in requested format for outline tree found in Soup
        element dl.
        """
        of = kwds['output_format']
        assert dl.name == 'dl', dl
        terms_root = dl.find('dt')
        if not terms_root: return
        terms_root = terms_root.parent
        terms = terms_root.find_all('dt', recursive=False)
        for term in terms:
            h3 = term.find('h3')
            if h3:
                #if of == 'rst':
                #    yield ''
                yield klass.format_folder_item(dl, i, **kwds)
                # Recurse
                subdl = nextSibling(h3)
                #sub = dl.find('dl', recursive=False)
                if subdl:
                    for s in klass.bm_html_soup_item_fmt(subdl, i+1,
                            **kwds):
                        yield s

                    #terms = subdl.find_all('dt', recursive=False)
                    #for dt in terms:
                    #    sl = klass.bm_html_soup_item_fmt(dt, i+1, **kwds)
                    #    for l in sl:
                    #        yield l
                    #if terms:
                    #    if of == 'rst':
                    #        yield ''

            else:
                a = term.find('a')
                if a:
                    if kwds['print_leafs']:
                        yield klass.format_leaf_item(term, i, **kwds)

    @classmethod
    def bm_html_soup_dl_fmt(klass, s, output_format, print_leafs):
        """Format a plain-text nested list from BeautifulSoup. Returns list of
        lines. """
        dls_root = s.find('dl').parent
        dls = dls_root.find_all('dl', recursive=False)
        ls = []
        if dls:
            for dl in dls:
                g = klass.bm_html_soup_item_fmt(dl, 1,
                        output_format=output_format, print_leafs=print_leafs)
                if g:
                    ls.extend( list(g) )
        return ls

    @classmethod
    def bm_html_soup_dlitems_gen(klass, dl, folder_f=_ttuple,
            item_f=_ttuple, stack=[]):
        assert dl.name == 'dl', dl
        terms_root = dl.find('dt')
        if not terms_root: return
        terms_root = terms_root.parent
        terms = terms_root.find_all('dt', recursive=False)
        for term in terms:
            h3 = term.find('h3')
            if h3:
                if stack:
                    h3.attrs['parent'] = stack[-1]
                    stack.append( stack[-1] + " / " + h3.text )
                else:
                    stack.append( h3.text )
                new_f = folder_f(h3.text, dict(h3.attrs))
                yield new_f
                subdl = nextSibling(h3)
                if subdl:
                    for it in klass.bm_html_soup_dlitems_gen(subdl,
                            folder_f=folder_f, item_f=item_f,
                            stack=stack):
                        yield it
                stack.pop()

            else:
                a = term.find('a')
                if a:
                    if stack:
                        a.attrs['parent'] = stack[-1]
                    yield item_f(a.text, dict(a.attrs))

        return

    @classmethod
    def bm_html_soup_items_gen(klass, s, folder_f=_ttuple,
            item_f=_ttuple):
        lists_root = s.find('dl').parent
        lists = lists_root.find_all('dl', recursive=False)
        if not lists:
            return
        for dl in lists:
            return klass.bm_html_soup_dlitems_gen(dl, folder_f=folder_f,
                    item_f=item_f)

    @classmethod
    def bm_html_soup_parse_to_sa(klass, soup, sa):
        importer = BmImporter(sa)

        def _folder(label, attrs):
            return label, attrs

        def _item(label, attrs):
            href = attrs['href']
            del attrs['href']

            # Dump data we will not handle
            if 'parent' in attrs:
                del attrs['parent']
            if 'icon' in attrs:
                del attrs['icon']

            if 'add_date' in attrs:
                ad = datetime.fromtimestamp(int(attrs['add_date']))
                del attrs['add_date']
            else:
                ad = None

            if 'last_modified' in attrs:
                lmd = datetime.fromtimestamp(int(attrs['last_modified']))
                del attrs['last_modified']
            else:
                lmd = None

            lctr = importer.init_locator(href, datetime.now())
            if not lctr:
                return

            bm = importer.init_bookmark(lctr, ad, label, None, None)
            #print(bm.name, lctr.to_dict())
            return bm

        items = klass.bm_html_soup_items_gen(soup, folder_f=_folder, item_f=_item)
        if not items:
            raise Exception("No definition lists in %s" % HTML)
        for it in items: pass


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

    """
    Helper during import of bookmarks into SQLAlchemy database.
    """

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
                log.std("Name already exists: %r at <%s>, not <%s>" % (name,
                    bm.location.ref, locator.ref))
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
        if not self.domains_stat:
            avgDomainFreq = 0
            hiDomainFreq = 0
        else:
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
        if not self.tags_stat:
            avgFreq = 0
            hiFreq = 0
        else:
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
