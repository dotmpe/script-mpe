#!/usr/bin/env python
"""
:created: 2013-12-30
:updated: 2014-08-26

- Import old bookmarks from JSON, XML.

::

    <tag>:GroupNode
        *<bm>:Bookmark

    Bookmark

"""
from __future__ import print_function
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.bookmarks2.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
chrome_bookmarks_path= '~/Library/Application Support/Google/Chrome/Default/Bookmarks'
__usage__ = """

Usage:
  bookmarks.py [options] dlcs (parse|import FILE|export)
  bookmarks.py [options] chrome (all|roots|groups) [--group-name NAME]...
  bookmarks.py [options] html (tree|groups) HTML
  bookmarks.py [options] stats
  bookmarks.py [options] (tag|href|domain) [NAME]
  bookmarks.py [options] list [NAME] [TAGS...]
  bookmarks.py [options] couchdb (stats|list)
  bookmarks.py [options] couchdb (sync|update) [NAME]
  bookmarks.py [options] couchdb (add|modify|remove) REF [ NAME [ TAGS... ] ]
  bookmarks.py [options] (add|modify|remove|assert) REF [ NAME ] [ TAGS... ]
  bookmarks.py [options] check [NAME]
  bookmarks.py [options] webarchive [NAME]
  bookmarks.py --background
  bookmarks.py -h|--help
  bookmarks.py --version

Options:
  -d REF --dbref=REF
                SQLAlchemy DB URL [default: %s]
  --couch=REF
                Couch DB URL [default: %s]
  --tag-offset INT
                Set import frequency-offset to exclude certain one-to-many
                relations if the usage is below given value.
                This entirely depends on usage.
                0 means to import everything [default: -1]
                Defaults to hiFreq * 0.1.
  --domain-offset INT
                Typical --*-offset, see before.
                Defaults to avgFreq. [default: -1]
  -s SESSION --session-name SESSION
                should be bookmarks [default: default].
  --chrome-bookmarks-path PATH
                [default: %s]
  --chrome-bookmarks-root GROUP
                [default: bookmark_bar]
  --group-name NAME
                Group name [default: bookmark_bar other]
  --output-format FMT
                json, repr [default: rst]
  --no-commit   .
  --commit      [default: true].
  --clear-unknown-keys
                Delete unknown keys from CouchDB documents.
  --newer-only
                Only update entries in target if source update time is more
                recent.
  --partial-match
                Treat input values as partial search values. This adds the
                equivalent of '*' around all the values (without '*').
  --deleted
  --days N
  --weeks N
  --status STATUS[,STATUS]
  --delete STATUS[,STATUS]
  --delete-error
  --include-null
  --ignore-last-seen
  --dry-run     Echo but don't make actual changes. This does all the
                document/record operations, but no commit.
  -v            Increase verbosity.
  --verbose     Default.
  -q, --quiet   Turn off verbosity.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).

""" % ( __db__, __couch__, chrome_bookmarks_path, __version__, )
from datetime import datetime, timedelta
import os
import re
import hashlib
import urllib
import urllib2
from urlparse import urlparse
import uriref
from pprint import pprint

import couchdb
#import zope.interface
#import zope.component
from pydelicious import dlcs_parse_xml
from sqlalchemy import or_
import BeautifulSoup

import log
import confparse
import libcmd_docopt
import libcmd
import rsr
import taxus.iface
import res.iface
import res.js
import res.bm
from res import Volumedir
from res.util import isodatetime, ISO_8601_DATETIME
from taxus import init as model
from taxus.init import SqlBase, get_session
from taxus.core import ID, Node, Name, Tag
from taxus.net import URL, Locator, Domain
from taxus.ns import Namespace, Localname
from taxus.model import Bookmark
from taxus.web import Resource, RemoteCachedResource

models = [ Locator, Tag, Domain, Bookmark, Resource, Namespace, Localname ]

#import bookmarks_model as model
#from bookmarks_model import Locator, Bookmark



class bookmarks(rsr.Rsr):

    #zope.interface.implements(res.iface.ISimpleCommand)

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    OPT_PREFIX = 'bm'
    OPTS_INHERIT = ('-v',)# '-q', '-i', '-c')

    DEFAULT_CONFIG_KEY = 'bm'

    #TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + ['']
    DEFAULT_ACTION = 'stats'

    DEPENDS = {
            'stats': ['rsr_session'],
            'list': ['rsr_session'],
            'add': ['rsr_session'],
            'add_lctr': ['rsr_session'],
            'list_lctr': ['rsr_session'],
            'add_lctr_ref_md5': ['rsr_session'],
            'add_ref_md5': ['rsr_session'],
            'moz_js_import': ['rsr_session'],
            'moz_js_group_import': ['rsr_session'],
            'moz_ht_import': ['rsr_session'],
            'dlcs_post_import': ['rsr_session'],
            'dlcs_post_read': ['rsr_session'],
            'dlcs_post_test': ['rsr_session'],
            'dlcs_post_test2': ['rsr_session'],
            'export': ['rsr_session']
        }

    @classmethod
    def get_optspec(Klass, inheritor):

        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (
            # actions
                p(('-s', '--stats',), libcmd.cmddict()),
                p(('-l', '--list',), libcmd.cmddict()),
                p(('-a', '--add',), libcmd.cmddict()),
                p(('--list-lctr',), libcmd.cmddict()),

                (('--moz-js-import',), libcmd.cmddict()),
                (('--dlcs-post-import',), libcmd.cmddict()),
                (('--dlcs-post-test',), libcmd.cmddict()),

                p(('--export',), libcmd.cmddict(help="TODO: bm export")),

                (('--moz-js-group-import',), libcmd.cmddict()),

                (('--add-lctrs',), libcmd.cmddict(
                    help="Add locator records for given URL's.")),
                (('--add-ref-md5',), libcmd.cmddict(
                    help="Add MD5-refs missing (on all locators). ")),

            # params
                p(('--public',), dict( action='store_true', default=False )),
                p(('--name',), dict( default=None, type="str" )),
                p(('--href',), dict( default=None, type="str" )),
                p(('--ext',), dict( default=None, type="str" )),
                p(('--tags',), dict( default=None, type="str" )),
                p(('--ref-md5',), dict( action='store_true',
                    default=False, help="Calculate MD5 for new locators. " )),
            )



    def assert_locator(self, sa=None, href=None, opts=None):
        lctr = Locator.fetch((Locator.global_id==href,), _sa=sa, exists=False)
        if not lctr:
            if len(href) > 255:
                log.err("Reference too long: %s", href)
                return
            lctr = Locator(
                    global_id=href,
                    date_added=datetime.now() )
            sa.add( lctr )
            if opts.rsr_auto_commit:
                sa.commit()
            if opts.bm_ref_md5:
                self.add_lctr_ref_md5(opts, sa, href)
        yield dict(lctr=lctr)


    def add_lctrs(self, sa=None, opts=None, *refs):
        if refs:
            for ref in refs:
                for ret in self.assert_locator( sa=sa, href=ref, opts=opts ):
                    yield ret['lctr']

    def add(self, sa=None, href=None, name=None, ext=None, public=False,
            tags=None, opts=None):
        "Create or update. alias --update?"
        lctr = [ r['lctr'] for r in self.assert_locator(sa=sa, href=href, opts=opts) ]
        if not lctr:
            yield dict( err="XXX Missed ref" )
        else:
            lctr = lctr.pop()
            assert lctr
            bm = Bookmark.fetch((Bookmark.ref==lctr,), _sa=sa, exists=False)
            if bm:
                # XXX: start local to bean dict
# XXXL name must be unique, must catch problems
                #if name != bm.name:
                #    bm.name = name
                #if lctr != bm.ref:
                #    bm.ref = lctr
                if ext != bm.extended:
                    bm.extended = ext
                if public != bm.public:
                    bm.public = public
                if tags != bm.tags:
                    bm.tags = tags
                bm.last_update = datetime.now()
            else:
                bm = Bookmark.fetch((Bookmark.name==name,), _sa=sa, exists=False)
                if bm:
                    log.err("Duplicate name %s", bm.name)
                    #bm.name = "%s (copy)" % name
                    bm = None
                else:
                    bm = Bookmark(
                            name=name,
                            ref=lctr,
                            extended=ext,
                            public=public,
                            tags=tags,
                        )
                    bm.init_defaults()
            if bm:
                assert bm.ref
                yield dict( bm=bm )
                sa.add(bm)
            if opts.rsr_auto_commit:
                sa.commit()


    def add_lctr_ref_md5(self, opts=None, sa=None, *refs):
        "Add locator and ref_md5 attr for URLs"
        if refs:
            if isinstance( refs[0], basestring ):
                opts.ref_md5 = True
                lctrs = [ ret['lctr'] for ret in self.add_lctrs(sa, opts, *refs) ]
                return
            else:
                assert isinstance( refs[0], Locator), refs
                lctrs = refs

            for lctr in lctrs:
                ref = lctr.ref or lctr.global_id
                ref_md5 = hashlib.md5( ref ).hexdigest()
                md5 = MD5Digest.fetch(( MD5Digest.digest == ref_md5, ),
                        exists=False)
                if not md5:
                    md5 = MD5Digest( digest=ref_md5,
                            date_added=datetime.now() )
                    sa.add( md5 )
                    log.info("New %s", md5)
                lctr.ref_md5 = md5
                sa.add( lctr )
                if opts.rsr_auto_commit:
                    sa.commit()
                log.note("Updated ref_md5 for %s to %s", lctr, md5)

    def add_ref_md5(self, opts=None, sa=None):
        "Add missing ref_md5 attrs. "
        lctrs = sa.query(Locator).filter(Locator.ref_md5_id==None).all()
        self.add_lctr_ref_md5( opts, sa, *lctrs )


    def moz_js_import(self, opts=None, sa=None, *paths):
        mozbm = res.bm.MozJSONExport()
        for path in paths:
            #for ref in mozbm.read_lctr(path):
            #    list(self.assert_locator(sa=sa, href=ref, opts=opts))
            for node in mozbm.read_bm(path):
                descr = [ a['value'] for a in node.get('annos', [] )
                        if a['name'] == 'bookmarkProperties/description' ]
                if 'uri' not in node or 'title' not in node or not node['title']:
                    log.warn("Illegal %s", node)
                else:
                    list(self.add(sa=sa,
                        href=node['uri'],
                        name=node['title'],
                        ext=descr and descr.pop() or None,
                        opts=opts))

    def moz_js_group_import(self, opts=None, sa=None, *paths):
        "Import groupnodes only. "
        mozbm = res.bm.MozJSONExport()
        for path in paths:
            nodes = {}
            roots = []
            #for ref in mozbm.read_lctr(path):
            #    list(self.assert_locator(sa=sa, href=ref, opts=opts))
            for node in mozbm.read(path):
                if 'title' in node and node['title'] and 'children' in node:
                    nodes[node['id']] = node
                    if 'root' in node:
                        roots.append(node)
            # TODO: store groups, but need to start at the root, sort out struct
            # XXX should need a tree formatter here
            print('Groups')
            for nid, node in nodes.items():
                #print repr(node['title']),
                if 'parent' in node:
                    parent = nodes[node['parent']]
                    self.rsr_add_group( node['title'], parent['title'],
                            sa=sa, opts=opts )
                else:
                    self.rsr_add_group( node['title'], None,
                            sa=sa, opts=opts )
            print('Roots')
            for root in roots:
                print(root['id'], root['title'])




def tojson( d ):
    for k in d:
        if isinstance(d[k], datetime):
            d[k] = d[k].isoformat()
    return d

def cmd_dlcs_import(opts, settings):
    """
    TODO: built into generic import/export (ie. complete set)  so heuristics can
        update all stats each import.. or find some way to fragment dataset.
    """
    importFile = opts.args.FILE
    data = dlcs_parse_xml(open(importFile).read())
    sa = URL.get_session('default', opts.flags.dbref)
    tags_stat = {}
    domains_stat = {}
    # first pass: validate, track stats and create URL records where missing
    for post in data['posts']:
        href = post['href']
        dt = datetime.strptime(post['time'], ISO_8601_DATETIME)
# validate URL
        url = urlparse(href)
        domain = url[1]
        if not domain:
            log.std("Ignored domainless (non-net?) URIRef: %s", href)
            continue
        assert re.match('[a-z0-9]+(\.[a-z0-9]+)*', domain), domain
# get/init URL
        lctr = URL.fetch((URL.ref == href,), exists=False)
        if lctr:
            if lctr.date_added != dt:
                lctr.date_added = dt
                sa.add(lctr)
        else:
            lctr = URL(
                    ref=href,
                    date_added=datetime.strptime(post['time'], ISO_8601_DATETIME)
                )
            lctr.init_defaults()
            log.std("new: %s", lctr)
            sa.add(lctr)
# get/init Bookmark
        bm = Bookmark.fetch((Bookmark.location == lctr,), exists=False)
        if bm:
            if bm.date_added != dt:
                bm.date_added = dt
                sa.add(bm)
            if bm.location != lctr:
                bm.ref = lctr
                sa.add(bm)
        else:
            bm = Bookmark.fetch((Bookmark.name == post['description'],), exists=False)
            if bm:
                log.std("Name already exists: %r" % post['description'])
                continue
            bm = Bookmark(
                    location=lctr,
                    name=post['description'],
                    extended=post['extended'],
                    tags=post['tag'].replace(' ', ', '),
                    date_added=datetime.strptime(post['time'], ISO_8601_DATETIME)
                )
            bm.init_defaults()
            log.std("new: %s", bm)
            sa.add(bm)
# track domain frequency
        if domain in domains_stat:
            domains_stat[domain] += 1
        else:
            domains_stat[domain] = 1
# track tag frequency
        for tag in post['tag'].split(' '):
            if tag in tags_stat:
                tags_stat[tag] += 1
            else:
                tags_stat[tag] = 1
    log.std("Checked %i locator references", len(data['posts']))
    sa.commit()
# Prepare domain stats
    avgDomainFreq = sum(domains_stat.values())/(len(domains_stat)*1.0)
    hiDomainFreq = max(domains_stat.values())
    log.std("Found domain usage (max/avg): %i/%i", hiDomainFreq, avgDomainFreq)
    domains = 0
    domainOffset = int(opts.flags.domain_offset)
    if domainOffset == 0:
        domainOffset = hiFreq
    elif domainOffset == -1:
        domainOffset = round(hiDomainFreq * 0.2)
    log.std("Setting domain-offset: %i", domainOffset)
# get/init Domains
    for domain in domains_stat:
        freq = domains_stat[domain]
        if freq >= domainOffset:
            domains += 1
            domain_record = Domain.fetch((Domain.name == domain,), exists=False)
            if not domain_record:
                domain_record = Domain(name=domain)
                domain_record.init_defaults()
                sa.add(domain_record)
    sa.commit()
    log.std("Checked %i domains", len(domains_stat))
    log.std("Tracking %i domains", domains)
# Prepare tag stats
    avgFreq = sum(tags_stat.values())/(len(tags_stat)*1.0)
    hiFreq = max(tags_stat.values())
    log.std("Found tag usage (max/avg): %i/%i", hiFreq, avgFreq)
    tagOffset = int(opts.flags.tag_offset)
    if tagOffset == 0:
        tagOffset = hiFreq
    elif tagOffset == -1:
        tagOffset = round(hiFreq * 0.1)
    log.std("Setting tag-offset: %i", tagOffset)
# get/init Tags
    tags = 0
    for tag in tags_stat:
        freq = tags_stat[tag]
        if not re.match('[A-Za-z0-9-]+', tag):
            log.std("Non-std tag %s", tag)
        if freq >= tagOffset:
            # Store tags only if count exceeds offset
            tags += 1
            t = Name.fetch((Name.name == tag,), exists=False)
            if not t:
                t = Tag(name=tag)
                t.init_defaults()
                log.std("new tag %r for %r", t, tag)
                sa.add(t)
            # store frequencies
            # TODO tags_freq
    log.std("Checked %i tags", len(tags_stat))
    log.std("Tracking %i tags", tags)
    sa.commit()

def cmd_html_groups(HTML, settings):
    data = open(HTML)
    soup = BeautifulSoup.RobustHTMLParser(data)
    res.bm.html_soup_formatters[of](soup, settings.output_format, False)

def cmd_html_tree(HTML, settings):
    data = open(HTML)
    soup = BeautifulSoup.RobustHTMLParser(data)
    print(res.bm.html_soup_formatters[settings.output_format](soup))


def cmd_chrome_all(settings):
    "List Chrome bookmarks (from JSON) in different formats"
    fn = os.path.expanduser(settings.chrome_bookmarks_path)
    bms = confparse.Values(res.js.load(open(fn)))
    # BUG: doopt 0.6.2. should split repeatable opt vals
    if not isinstance(settings.group_name, list):
        settings.group_name = settings.group_name.split(' ')
    for group_name in settings.group_name:
        group = confparse.Values(bms.roots[group_name])
        res.bm.moz_json_printer[settings.output_format](group)

def cmd_chrome_groups(settings):
    "List Chrome bookmarks folders only (from JSON) in different formats"
    fn = os.path.expanduser(settings.chrome_bookmarks_path)
    bms = confparse.Values(res.js.load(open(fn)))
    groups = bms.roots.keys()
    of = settings.output_format
    if of == 'json':
        print(res.js.dumps(dict(
            version=bms.version,
            checksum=bms.checksum,
            groups=groups
        )))
    else:
        for group_name in groups:
            print(group_name)


def cmd_html_check(HTML, settings):
    print(HTML)


def cmd_stats(settings):
    sa = get_session(settings.dbref)
    for stat, label in (
                (sa.query(Locator).count(), "Number of URLs: %s"),
                (sa.query(Bookmark).count(), "Number of bookmarks: %s"),
                (sa.query(Domain).count(), "Number of domains: %s"),
                (sa.query(Tag).count(), "Number of tags: %s"),
            ):
        log.std(label, stat)
    for lctr in sa.query(Locator).filter(Locator.global_id==None).all():
        lctr.delete()
        log.note("Deleted Locator without global_id %s", lctr)
    for bm in sa.query(Bookmark).filter(Bookmark.ref_id==None).all():
        bm.delete()
        log.note("Deleted bookmark without ref %s", bm)


def cmd_href(NAME, settings):
    """List hyper-references"""
    sa = Locator.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Locator.search(ref=NAME)
    else:
        rs = Locator.all()
    if not rs:
        log.std("Nothing")
    for r in rs:
        print(r.ref)


def cmd_tag(NAME, settings):
    """List tags"""
    sa = Tag.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Tag.search(name=NAME)
    else:
        rs = Tag.all()
    if not rs:
        log.std("Nothing")
    for r in rs:
        print(r.name)


def cmd_domain(NAME, settings):
    """List domains"""
    sa = Domain.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Domain.search(name=NAME)
    else:
        rs = Domain.all()
    if not rs:
        log.std("Nothing")
    for r in rs:
        print(r.name)


def cmd_list(NAME, TAGS, settings, opts):

    """
    List bookmarks given NAME, TAGS filter.

    Asterisks '*' in any of the input is turned into a like expression, to
    make patterns for matching on partial values.
    """

    def _like_val(field, value):
        if '*' in value:
            return field.like( value.replace('*', '%') )
        elif opts.flags.partial_match:
            return field.like( '%'+value+'%' )
        else:
            return field == value

    tag_filters = ()
    if TAGS:
        tag_filters = tuple([ _like_val(Bookmark.tags, T) for T in TAGS ])

    sa = Bookmark.get_session(settings.session_name, settings.dbref)
    if NAME:
        if TAGS:
            rs = Bookmark.all(filters=( _like_val(Bookmark.name, NAME) ) )
        else:
            rs = Bookmark.search(name=NAME)
    else:
        if TAGS:
            rs = Bookmark.all(filters=tag_filters)
        else:
            rs = Bookmark.all()
    if not rs:
        log.std("Nothing")

    of = settings.output_format
    if of == 'json':
        def out( d ):
            for k in d:
                if isinstance(d[k], datetime):
                    d[k] = d[k].isoformat()
            return res.js.dumps(d)
    else:
        tpl = taxus.out.get_template("bookmark.%s" % of)
        out = tpl.render

    for bm in rs:
        d = bm.to_dict()
        d['tags'] = ', '.join(d['tags'])
        print(out( d ))

    print('%i found' % len(rs))


def cmd_check(NAME, settings):

    """
    Update last-seen time.

    Visit the URL for each bookmark, and update the last-seen date if
    successful. Options below apply filters and specific actions.

    If no filters are provided, the default is to select URLs not seen in
    the last 52 weeks, and all those without status or last-seen fields.

    --deleted
    --weeks, --days
        Select only locators not seen within the last N weeks or days.
    --status [xxx]
        Select only locators with last recorded status.
    --include-null
        Applies to last-seen, dont exclude null (weeks, days, status)
    --delete [0,4,5,xxx]
        On resolve or HTTP error delete the Locator.

        To delete only on specific
        cases, pass 0 for just name resolution or network errors, a single
        digit for 4xx or 5xxx errors, or any specific HTTP status code.
    --delete-error
        Shortcut to --delete 0,4,5
    """

    sa = Locator.get_session(settings.session_name, settings.dbref)

    delete = []
    if opts.flags.delete_error:
        delete = [ 0, 4, 5 ]
    elif opts.flags.delete:
        delete = [ int(i) for i in opts.flags.delete.split(',') ]

    f = []

    if opts.flags.status:
        for s in opts.flags.status.split(','):
            if s > 99:
                if opts.flags.include_null:
                    f.append(or_(
                        Resource.status.is_(None),
                        Resource.status == s
                    ))
                else:
                    f.append( Resource.status == s )
            else:
                if opts.flags.include_null:
                    f.append(or_(
                        Resource.status.is_(None),
                        Resource.status >= s*100 and Resource.status < (s+1)*100
                    ))
                else:
                    f.append(
                        Resource.status >= s*100 and Resource.status < (s+1)*100
                    )

    if opts.flags.weeks:
        w = int(opts.flags.weeks)
        if opts.flags.include_null:
            f.append(or_(
                Resource.last_access.is_(None),
                Resource.last_access < (
                    datetime.utcnow() - timedelta(weeks=w))
            ))
        else:
            f.append( Resource.last_access < (
                datetime.utcnow() - timedelta(weeks=w)) )

    elif opts.flags.days:
        d = int(opts.flags.days)
        if opts.flags.include_null:
            f.append(sa.or_(
                Resource.last_access.is_(None),
                Resource.last_access < (datetime.utcnow() - timedelta(days=d))
            ))
        else:
            f.append( Resource.last_access < (
                datetime.utcnow() - timedelta(days=d)) )

    if not f:
        if opts.flags.include_null:
            f.append(or_(
                    Resource.last_access < (
                        datetime.utcnow() - timedelta(weeks=52)),
                    Resource.status.is_(None)
                ))
        else:
            f.append(or_(
                    Resource.last_access < (
                        datetime.utcnow() - timedelta(weeks=52)),
                    Resource.last_access.is_(None),
                    Resource.status.is_(None)
                ))

    if not opts.flags.deleted:
        f.append( Resource.deleted!=True )

    rs = Resource.all(f)
    print('%i URL\'s to check' % len(rs))

    for i, r in enumerate(rs):
        ref = r.location.href()
        print(i, r.status, r.deleted, r.last_access, ref)
        if i > 0 and ( i % 10 ) == 0:
            sa.commit()
            print('committed at %s items, %i to go' % ( i, len(rs)-i ))

        try:
            urlinfo = urllib2.urlopen(ref, timeout=9)
        except urllib2.HTTPError as e:
            r.status = e.code
            if e.code in delete:
                r.delete()
            sa.add(r)
            continue
        except urllib2.URLError as e:
            r.status = -2
            if 0 in delete or -1 in delete:
                r.delete()
            sa.add(r)
            continue
        except Exception as e:
            print(e, ref)
            r.status = -1
            if 0 in delete or -1 in delete:
                r.delete()
            sa.add(r)
            print(0, ref)
            continue

        info = urlinfo.info()
        status = urlinfo.getcode()
        if r.status == None or status != r.status:
            r.status = status
            sa.add(r)
            print(status, ref)

        if status == 200:
            r.last_access = datetime.now()
            sa.add(r)

        if status and ( status in delete or status/100 in delete ):
            r.delete()
            sa.add(r)

        #print i, r.status, r.deleted, r.last_access, ref
    sa.commit()



def cmd_assert(REF, NAME, TAGS, settings):

    """
    Create an URL record if it does not exist yet.

    If NAME and optionally TAGS is given, create a bookmark too but only
    if it does not exist yet.
    """

    sa = Bookmark.get_session(settings.session_name, settings.dbref)

    lctr = URL.fetch((URL.ref == REF,), exists=False)
    if not lctr:
        lctr = URL( ref=REF, date_added=datetime.now() )
        lctr.init_defaults()
        log.std("new: %s", lctr)
        if not settings.dry_run:
            sa.add(lctr)

    bm = Bookmark.fetch((Bookmark.location == lctr,), exists=False)
    if NAME and not bm:
        bm = Bookmark.fetch((Bookmark.name == NAME,), exists=False)
        if bm:
            log.std("Name already exists for other location: %r at %r vs %r"
                    % ( NAME, REF, bm.href ))
        else:
            bm = Bookmark.from_dict(location=lctr, name=NAME, tags=TAGS)
            bm.init_defaults()
            log.std("new: %s", bm)
            if not settings.dry_run:
                sa.add(bm)

    if settings.dry_run:
        log.std("Dry run")
    else:
        sa.commit()



def cmd_webarchive(NAME, settings):
    """
    Sort out and rewrite web.archive locators.

    http://web.archive.org/web/20030208015752/
    """
    sa = Bookmark.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Bookmark.search(name=NAME)
    else:
        rs = Bookmark.all()
    if not rs:
        log.std("Nothing")
        return

    NS_WA = 'http://web.archive.org/web'
    ns_lctr = URL.fetch((URL.ref == NS_WA,), exists=False)
    if not ns_lctr:
        ns_lctr = URL( ref=NS_WA )
        ns_lctr.init_defaults()
        sa.add(ns_lctr)

    rcres_type = Namespace.fetch(( Namespace.location == ns_lctr ,),
            exists=False)
    if not rcres_type:
        rcres_type = Namespace( location=ns_lctr )
        rcres_type.init_defaults()
        sa.add(rcres_type)

    sa.commit()

    i = 0
    for r in rs:
        if 'web.archive.org/web' in r.href:
            i += 1
            cache_path = r.href.split('web.archive.org/web/')[1]
            p = cache_path.index('/')

            res_ts = cache_path[:p]
            res_url = cache_path[p+1:]
            if not uriref.absoluteURI.match(res_url):
                res_url = 'http://'+res_url

            lctr = URL.fetch((URL.ref == res_url ,), exists=False)
            if not lctr:
                lctr = URL( ref=res_url )
                lctr.init_defaults()
                log.std("New: %s", lctr.href() )
                sa.add(lctr)

            if res_ts.isdigit():
                DT_FMT='%Y%m%d%H%M%S'
                dt = datetime.strptime(res_ts, DT_FMT)
            else:
                log.err("Unknown date tag: %s", res_ts)
                continue

            rcres = RemoteCachedResource( location=lctr, rcres_type=rcres_type,
                    last_access=r.last_access,
                    last_update=r.last_update,
                    last_modified=r.last_modified,
                    status=r.status,
                    date_added=r.date_added,
                    date_deleted=r.date_deleted,
                    date_updated=dt )

            sa.add(rcres)
            sa.delete(r)
            #sa.commit()

            print('TODO %s' % lctr.href())

    log.std("Found %i instances", i)
    #sa.commit()


def cmd_couchdb_update(settings):

    """
    Update SQL DB Bookmark records from CouchDB.
    """

    ref, dbname = settings.couch.rsplit('/', 1)
    server = couchdb.client.Server(ref)
    db = server[dbname]

    sa = Bookmark.get_session(settings.session_name, settings.dbref)
    for idref in db:
        doc = db[idref]
        href = db['href']

        lctr = URL.fetch((URL.ref == href,), exists=False)
        if not lctr:
            lctr = URL.from_dict(**doc)
            lctr.init_defaults()
            log.std("new: %s", lctr)
            if not settings.dry_run:
                sa.add(lctr)

        bm = Bookmark.fetch((Bookmark.location == lctr,), exists=False)
        if not bm:
            bm = Bookmark.fetch((Bookmark.name == doc['name'],), exists=False)
            if bm:
                log.std("Name already exists for other location: %r at %r vs %r"
                        % ( doc['name'], href, bm.href ))
                continue
            bm = Bookmark.from_dict(location=lctr, **doc)
            bm.init_defaults()
            log.std("new: %s", bm)
            if not settings.dry_run:
                sa.add(bm)

        if bm.update_from(location=lctr, **doc):
            if not settings.dry_run:
                sa.add(bm)
            log.std("updated: %s", href)

    if not settings.dry_run:
        sa.commit()


def cmd_couchdb_sync(NAME, ctx, opts, settings):

    """
    Update CouchDB bookmark-type documents from SQL.
    """

    ref, dbname = settings.couch.rsplit('/', 1)
    server = couchdb.client.Server(ref)
    db = server[dbname]

    sa = Bookmark.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Bookmark.search(name=NAME)
    else:
        rs = Bookmark.all()
    if not rs:
        log.std("Nothing")
        return

    if opts.flags.verbose:
        print('Going to sync %i SQL records to %s...' % ( len(rs), dbname ))

    new = []
    updates = []
    for r in rs:

        # NOTE: simply mapping column-names in result to couchdb doc
        d = tojson( r.to_dict() )
        d['type'] = 'bookmark'

        href = d['href']
        idref = hashlib.sha256(href).hexdigest()
        if idref in db or href in db:

            updated = False

            # 'upgrade' bare URL key entry
            map_id = href in db
            if map_id:
                c = db[href]
            else:
                c = db[idref]

            # NOTE: not doing anything else than bookmarks
            if c['type'] != 'bookmark':
                print(
                    "Document {0} exists but is not of required type: {1}".format(
                    href, c['type']),
                    file=opts.stderr)
                continue

            # We can stop right there.
            if r.deleted:
                if c['deleted']:
                    continue
                c['deleted'] = true
                c['date_deleted'] = r.date_deleted
                # Soft delete, for archival/cleanup by someone else.
                continue

            # Check on update time to things speed up
            if opts.flags.clear_unknown_keys:
                c_dt = isodatetime(c['date_updated'])
                if c_dt >= r.date_updated:
                    continue

            # Delete missing keys
            if opts.flags.clear_unknown_keys:
                for k in c.keys():
                    if k in [ '_rev', '_id', 'type' ]:
                        continue
                    if k not in d:
                        del c[k]
                        updated = True

            # Set new or changed values
            for k in d.keys():
                if k not in c or c[k] != d[k]:
                    c[k] = d[k]
                    updated = True
            if updated or map_id:
                c['date_updated'] = r.date_updated.isoformat()
                if not settings.dry_run:
                    if map_id:
                        del db[href]
                        db[idref] = c
                    else:
                        db.update([c])
                updates.append(c)
                if opts.flags.verbose:
                    print('updated %s' % href)

        else:

            # New entry
            if not settings.dry_run:
                db[idref] = d
            new.append(d)
            if opts.flags.verbose:
                print('new %s' % href)

    print('%i new' % len(new))
    print('%i updated' % len(updates))


def cmd_couchdb_stats(settings):

    ref, dbname = settings.couch.rsplit('/', 1)
    server = couchdb.client.Server(ref)

    stats = server.stats()
    print('# couchdb-stat current max min mean stddev sum description')
    for k in stats['couchdb']:
        print(k, end=' ')
        for k2 in 'current', 'max', 'min', 'mean', 'stddev', 'sum', 'description':
            print(stats['couchdb'][k][k2], end=' ')
        print()


def cmd_couchdb_list(settings):

    ref, dbname = settings.couch.rsplit('/', 1)
    server = couchdb.client.Server(ref)

    db = server[dbname]
    for _id in db:
        doc = db[_id]
        if ( hasattr(doc, 'type') and doc.type == 'bookmark' ) or 'href' in doc:
            print(doc['href'])


def cmd_couchdb_add(URL, TITLE, TAGS, settings):

    ref, dbname = settings.couch.rsplit('/', 1)
    opts.flags.couchdb = dbname

    server = couchdb.client.Server(ref)
    db = server[dbname]

    print(server, dbname, URL, TITLE, TAGS)
    db[URL] = {
      'type': 'bookmark',
      'href': URL,
      'tags': TAGS
    }


"""
TODO: sync shaarli either from SQL or couch.

Also google/firefox bookmarks, chrome outliner.
"""

from shaarli_client.client import ShaarliV1Client, InvalidEndpointParameters


def cmd_shaarli_update(settings):
    """
    Update SQL DB Bookmark records from Shaarli.
    """

def cmd_shaarli_sync(NAME, opts, settings):
    """
    Update Shaarli bookmark-type documents from SQL.
    """


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help

### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute using docopt-mpe options.
    """

    settings = opts.flags
    opts.flags.commit = not opts.flags.no_commit
    opts.flags.verbose = not opts.flags.quiet
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'bookmarks.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    # TODO : vdir = Volumedir.find()

    db = os.getenv( 'BOOKMARKS_DB', __db__ )
    if db is not __db__:
        __usage__ = __usage__.replace(__db__, db)

    couch = os.getenv( 'COUCH_DB', __couch__ )
    if couch is not __couch__:
        __usage__ = __usage__.replace(__couch__, couch)

    opts = libcmd_docopt.get_opts(__doc__ + __usage__, version=get_version())
    opts.stderr = sys.stderr
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    # TODO: mask secrets
    #log.std("Connecting to %s", opts.flags.dbref)
    #log.std("Connecting to %s", opts.flags.couch)
    sys.exit(main(opts))
