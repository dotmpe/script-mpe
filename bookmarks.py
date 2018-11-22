#!/usr/bin/env python
"""
:Created: 2013-12-30
:Updated: 2018-03-09

- Import old bookmarks from JSON, XML.

Commands:
  - list
  - add | modify | assert | show
  - remove
  - tags
  - urls
  - sync

  Database:
    - info | init | stats | clear
"""
from __future__ import print_function

__description__ = "bookmarks - ..."
__short_description__ = "..."
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.bookmarks.sqlite'
__couch__ = 'http://localhost:5984/the-registry'
chrome_bookmarks_path= '~/Library/Application Support/Google/Chrome/Default/Bookmarks'
chrome_history_path=   '~/Library/Application Support/Google/Chrome/Default/History'
__usage__ = """

Usage:
  bookmarks.py [-v... options] list [NAME] [ --tags=TAG... ]
  bookmarks.py [-v... options] (add|modify|assert|show) REF [ NAME ] [ TAGS... ]
  bookmarks.py [-v... options] remove REF
  bookmarks.py [-v... options] tags [TAGS...]
  bookmarks.py [-v... options] urls REF
  bookmarks.py [-v... options] sync
  bookmarks.py [-v... options] check [NAME]
  bookmarks.py [-v... options] webarchive [NAME]
  bookmarks.py [-v... options] (tag|href|domain) [NAME]
  bookmarks.py [-v... options] x [ARG...]
  bookmarks.py [-v... options] dlcs (parse|import FILE|export)
  bookmarks.py [-v... options] chrome (all|roots|groups) [--group-name NAME]...
  bookmarks.py [-v... options] html (tree|groups|import) HTML
  bookmarks.py [-v... options] sql (stats|couch)
  bookmarks.py [-v... options] couch (sql|stats|list|update|init)
  bookmarks.py [-v... options] couch (add|modify) REF [ NAME [ TAGS... ] ]
  bookmarks.py [-v... options] info | init | stats | clear | memdebug
  bookmarks.py --background
  bookmarks.py -h|--help
  bookmarks.py help [CMD]
  bookmarks.py --version

Options:
  -s SESSION, --session-name SESSION
                should be bookmarks [default: default].
  -d REF, --dbref=REF
                SQLAlchemy DB URL [default: %s]
  --no-db       Don't initialize SQL DB connection.
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
  --chrome-bookmarks-path PATH
                [default: %s]
  --chrome-bookmarks-root GROUP
                [default: bookmark_bar]
  --group-name NAME
                Group name [default: bookmark_bar other]
  -O FMT, --output-format FMT
                json, repr [default: rst]
  -i N, --interval N
                Be verbose at least every N records [default: 100]
  --interactive
                Prompt to resolve or override certain warnings.
                XXX: Normally interactive should be enabled if while process has a
                terminal on stdin and stdout.
  --batch
                Overrules `interactive`, exit on errors or strict warnings.
  --auto-commit N
                Auto-commit every N records.
  --no-commit   .
  --commit      [default: true].
  --clear-unknown-keys
                Delete unknown keys from CouchDB documents.
  --newer-only
                Only update entries in target if source update time is more
                recent.
  --no-partial-match
  --partial-match
                Treat input values as partial search values. This adds the
                equivalent of '*' around all the values (without '*').
  --update-hrefids
                Walk over URLs (.href) and rename if found as key.
  --update-tagstype
                Correct couch document 'tags->tag_list' attribute.
  --deleted
  --count       [default: false].
  --status STATUS[,STATUS]
  --days N
  --weeks N
  --from DATE
  --to DATE
  --on DAY
  --older-than SPEC
  --max-age SPEC
                Datetime query window. [Default: 1y] Queries are always on
                updated-time's.
  --added       Use added time instead of update in match with date/time.
  --matched-only
  --exact-match
  --struct-output
  --update
  --delete STATUS[,STATUS]
  --delete-error
  --include-null
  --ignore-last-seen
  --dry-run     Echo but don't make actual changes. This does all the
                document/record operations, but no commit.
  -v, --verbose  Increase verbosity, 3 is maxumim.
  -q, --quiet   Turn off verbosity. Overrides verbosity flags.
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).
""" % ( __db__, __couch__, chrome_bookmarks_path, __version__, )
import os
import sys
import hashlib
import urllib
import urllib2
from datetime import datetime, timedelta

import uriref
from pydelicious import dlcs_parse_xml
import BeautifulSoup

from script_mpe.libhtd import *
from script_mpe.bookmarks_model import *
from script_mpe.res import bm_chrome

ctx = Taxus(version='bookmarks')

cmd_default_settings = dict(
        verbose=1,
        partial_match=True,
        strict=True
    )


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
                    help="Add locator records for given Locator's.")),
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
        "Add locator and ref_md5 attr for Locators"
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


### Commands


def cmd__dlcs_import(FILE, opts, g):

    """
    Import from (old pre-2009) del.icio.us posts XML export using
    pydelicious library.
    """
    global ctx

    importer = res.bm.BmImporter(ctx.sa_session)
    data = dlcs_parse_xml(open(FILE).read())

    # Validate URL, track tag/domain and create records where missing
    for post in data['posts']:
        href = post['href']
        dt = datetime.strptime(post['time'], ISO_8601_DATETIME)
        lctr = importer.init_locator(href, dt)
        if not lctr:
            continue

        tagcsv = unicode(post['tag'].replace(' ', ', '))
        bm = importer.init_bookmark(lctr, dt,
                post['description'], post['extended'], tagcsv )
        if not bm:
            continue

        # commit every x records
        importer.batch_flush(g)

    log.std("Checked %i locator references", len(data['posts']))
    importer.flush(g)

    # proc/fetch/init Domains
    importer.flush_domains(g)

    # proc/fetch/init Tags
    importer.flush_tags(g)


def cmd__html_groups(HTML, g):
    """
    TODO: work on just the groups (folders) extracted from the bookmark.html.
    """
    soup = BeautifulSoup.RobustHTMLParser(open(HTML))
    print(res.bm.html_soup_formatters[g.output_format](soup))

def cmd__html_tree(HTML, g):
    """
    Extract folder/bookmark item lines from HTML.
    """
    soup = BeautifulSoup.RobustHTMLParser(open(HTML))
    print(res.bm.html_soup_formatters[g.output_format](soup))

def cmd__html_import(HTML, g):
    """
    """
    global ctx
    soup = BeautifulSoup.RobustHTMLParser(open(HTML))
    importer = res.bm.BmImporter(ctx.sa_session)

    def _folder(label, attrs):
        return label, attrs
    def _item(label, attrs):
        href = attrs['href']
        del attrs['href']
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
        print(label, attrs)

        bm = importer.init_bookmark(lctr, ad, label, None, None)
        return bm

    items = res.bm.TxtBmOutline.bm_html_soup_items_gen(soup,
            folder_class=_folder, item_class=_item)
    if not items:
        raise Exception("No definition lists in %s" % HTML)
    for it in items:
        pass#print(it)


def cmd__chrome_all(g):
    "List Chrome bookmarks (from JSON) in different formats"
    fn = os.path.expanduser(g.chrome_bookmarks_path)
    bms = confparse.Values(res.js.load(open(fn)))
    # BUG: docopt 0.6.2. should split repeatable opt vals
    if not isinstance(g.group_name, list):
        g.group_name = g.group_name.split(' ')
    for group_name in g.group_name:
        group = confparse.Values(bms.roots[group_name])
        res.bm.moz_json_printer['item'][g.output_format](group)

def cmd__chrome_groups(g):
    "List Chrome bookmarks folder paths (from JSON)"
    fn = os.path.expanduser(g.chrome_bookmarks_path)
    bms = bm_chrome.BookmarksJSON.load(fn)

    for it in bm_chrome.flatten_norecurse(list(bms.groups())):
        print(it)


def cmd__sql_stats(g):
    global ctx
    sa = ctx.sa_session
    for stat, label in (
                (sa.query(Locator).count(), "Number of Locators: %s"),
                (sa.query(Bookmark).count(), "Number of bookmarks: %s"),
                (sa.query(Domain).count(), "Number of domains: %s"),
                (sa.query(Tag).count(), "Number of tags: %s"),
            ):
        log.std(label, stat)
    #for lctr in sa.query(Locator).filter(Locator.global_id==None).all():
    #    lctr.delete()
    #    log.note("Deleted Locator without global_id %s", lctr)
    #for bm in sa.query(Bookmark).filter(Bookmark.ref_id==None).all():
    #    bm.delete()
    #    log.note("Deleted bookmark without ref %s", bm)


def cmd__href(NAME, g):
    """List hyper-references"""
    sa = Locator.get_session(g.session_name, g.dbref)
    if NAME:
        rs = Locator.search(ref=NAME)
    else:
        rs = Locator.all()
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict:
            return 1
    for r in rs:
        print(r.ref)


def cmd__domain(NAME, g):
    """List domains"""
    sa = Domain.get_session(g.session_name, g.dbref)
    if NAME:
        rs = Domain.search(name=NAME)
    else:
        rs = Domain.all()
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict:
            return 1
    for r in rs:
        print(r.name)


def cmd__tag(NAME, g):
    """Get tag"""
    sa = Tag.get_session(g.session_name, g.dbref)
    if NAME:
        rs = Tag.search(name=NAME)
    else:
        rs = Tag.all()
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict:
            return 1
    for r in rs:
        print(r.name)


def cmd__tags(TAGS, g):
    """
    Dump all tags found on bookmarks. Filter by given tag, fuzzy by default.
    Print all tags, ie. related tags (on the same record) too.
    """
    global ctx

    tags = Bookmark.unique_tags(TAGS, g, ctx)
    if tags:
        for t in tags:
            if g.matched_only:
                if g.exact_match:
                    if t in TAGS:
                        print(t)
                else:
                    for n in TAGS:
                        if n in t:
                            print(t)
            else:
                print(t)
        ctx.note("%i unique tags found on bookmarks", len(tags))


def cmd__urls(REF, g, opts):
    """List URLs from SQL.

    Unless --exact-match is given, inputs are turned into LIKE expressions for
    partial match.
    """
    global ctx

    filters = ctx.opts_to_filters(Locator)
    if REF:
        filters += ( sql_like_val(Locator.ref, REF, g), )
    if g.count:
        cnt = ctx.sa_session.query(Locator).filter(*filters).count()
        log.std("Records matched: %s", cnt)
        return
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict: return 1
    for r in rs:
        print(r)
    # FIXME ctx.lines_out(rs)


def cmd__list(NAME, g, opts):

    """
    List bookmarks given NAME, TAGS filter from SQL.

    All matches are partial (delimited by '%' and turned into LIKE expression),
    unless --exact-match is given.
    Asterisks '*' in any of the inputs are also handled as explicit LIKE expression.
    """
    global ctx

    filters = ctx.opts_to_filters(Bookmark)
    if g.tags:
        filters += tuple([ sql_like_val(Bookmark.tags, T) for T in g.tags ])
    if NAME:
        filters += ( sql_like_val(Bookmark.name, NAME), )

    if g.count:
        cnt = ctx.sa_session.query(Bookmark).filter(*filters).count()
        log.std("Records matched: %s", cnt)
        return

    rs = Bookmark.all(filters=filters)
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict:
            return 1
        return

    render = ctx.get_renderer('bookmark')
    for r in rs:
        print(render(r.to_dict()))
    ctx.flush()
    print('%i found' % len(rs))


def cmd__add(REF, NAME, TAGS, g, sa=None):
    global ctx
    bm = Bookmark.forge(REF, NAME, TAGS, g, ctx.sa_session)
    print(ctx.get_renderer('bookmark')(bm.to_dict()))


def cmd__modify(REF, g):
    assert 'todo'


def cmd__remove(REF, g):
    "Soft-delete Bookmark and Locator by Locator"
    global ctx
    sa = ctx.sa_session

    lctr = sa.query(Locator).filter(Locator.ref == REF).one()
    bm = sa.query(Bookmark).filter(Bookmark.location == lctr).one()

    bm.delete()
    lctr.delete()
    if not g.dry_run:
        sa.add(lctr)
        sa.add(bm)
        sa.commit()
        ctx.note("Deleted %s", REF)
    print(lctr, bm)


def cmd__check(NAME, g):

    """
    Update last-seen time.

    Visit the Locator for each bookmark, and update the last-seen date if
    successful. Options below apply filters and specific actions.

    If no filters are provided, the default is to select Locators not seen in
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

    sa = Locator.get_session(g.session_name, g.dbref)

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
    print('%i Locator\'s to check' % len(rs))

    for i, r in enumerate(rs):
        ref = r.location.href()
        print(i, r.status, r.deleted, r.last_access, ref)
        if i and ( i % 10 ) == 0:
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
        except urllib2.LocatorError as e:
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


def cmd__assert(REF, NAME, TAGS, g):

    """
    Create an Locator record if it does not exist yet.

    If NAME and optionally TAGS is given, create a bookmark too but only
    if it does not exist yet.
    """

    sa = Bookmark.get_session(g.session_name, g.dbref)
    bm = Bookmark.forge(REF, NAME, TAGS, g, sa)
    print(bm)
    if g.dry_run:
        log.std("Dry run")
    else:
        sa.commit()


def cmd__show(REF, NAME, TAGS, g):
    global ctx
    sa = ctx.sa_session
    filters = ()
    if not g.deleted:
        filters = ( Bookmark.deleted != True, )

    if REF:
        lctr = sa.query(Locator).filter(Locator.ref == REF).one()
        filters += ( Bookmark.location == lctr, )

    if TAGS:
        filters += tuple([ sql_like_val(Bookmark.tags, T, g) for T in TAGS ])

    if NAME:
        filters += ( sql_like_val(Bookmark.name, NAME, g), )

    if filters:
        rs = Bookmark.all(filters=filters)
    else:
        rs = Bookmark.all()
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict:
            return 1
        return

    ctx.out(rs, 'bookmark')
    ctx.note("%i items", len(rs))


def cmd__webarchive(NAME, g):

    """
    Sort out and rewrite web.archive locators.


    http://web.archive.org/web/20030208015752/
    """
    global ctx
    sa = ctx.sa_session

    NS_WA = 'http://web.archive.org/web'
    ns_lctr = Locator.fetch((Locator.ref == NS_WA,), exists=False)
    if not ns_lctr:
        ns_lctr = Locator( ref=NS_WA )
        ns_lctr.init_defaults()
        sa.add(ns_lctr)

    rcres_type = Namespace.fetch(( Namespace.location == ns_lctr ,),
            exists=False)
    if not rcres_type:
        rcres_type = Namespace( location=ns_lctr )
        rcres_type.init_defaults()
        sa.add(rcres_type)

    if g.commit:
        sa.commit()


    rs = sa.query(Locator).filter(
            Locator.ref.like('%/web.archive.org/web/%'),
            Locator.deleted != True).all()
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict:
            return 1
        return
    total_records = len(rs)

    i = 0
    for lctr in rs:
        assert 'web.archive.org/web' in lctr.ref

        i += 1
        bm = Bookmark.fetch((Bookmark.location == lctr,), exists=False)
        if not bm:
            continue

        cache_path = lctr.ref.split('web.archive.org/web/')[1]
        p = cache_path.index('/')
        res_ts = cache_path[:p]
        res_url = cache_path[p+1:]
        if not uriref.absoluteURI.match(res_url):
            res_url = 'http://'+res_url

        lctr_new = Locator.fetch((Locator.ref == res_url,), exists=False)
        if not lctr_new:
            lctr_new = Locator( ref=res_url )
            lctr_new.init_defaults()
            log.std("New: %s", lctr_new.href() )

        if res_ts.isdigit():
            DT_FMT='%Y%m%d%H%M%S'
            dt = datetime.strptime(res_ts, DT_FMT)
        else:
            log.err("Unknown date tag: %s", res_ts)
            continue

        rcres = RemoteCachedResource( location=lctr, rcres_type=rcres_type,
                last_access=bm.last_access,
                last_update=bm.last_update,
                last_modified=bm.last_modified,
                status=bm.status,
                date_added=lctr.date_added,
                date_deleted=lctr.date_deleted,
                date_updated=dt )

        if not g.dry_run:
            sa.add(lctr_new)
            sa.add(rcres)
            #sa.delete(lctr)
        if g.auto_commit and i and i % g.auto_commit == 0:
            if g.verbose > 1:
                ctx.note("Auto-commit at %i of %i", i, total_records)
            sa.commit()

        ctx.note('TODO %s', lctr.href())
    if g.commit:
        sa.commit()
    ctx.note("Found %i instances", i)


def cmd__sync(g): pass
def cmd__update(g): pass
def cmd__x(g):

    """
    XXX: hacky hack hack
    """


def cmd__couch_stats(g):
    global ctx
    stats = ctx.couchconn.stats()
    print('# couchdb-stat current max min mean stddev sum description')
    for k in stats['couchdb']:
        print(k, end=' ')
        for k2 in 'current', 'max', 'min', 'mean', 'stddev', 'sum', 'description':
            print(stats['couchdb'][k][k2], end=' ')
        print()


couch_views = {
    '_design/bookmarks': dict( views=dict( list=dict( map= """function(doc) {

    if (doc.type && doc.type == 'bookmark') emit(doc.id, doc.href);

}"""))),
}


def cmd__couch_init(g):

    """
    /<db-name>/_design/<design-doc>/_view/<view-name>
    """
    global ctx

    for k, v in couch_views.items():
        if k in ctx.docs:
            if g.update:
                ctx.note("Updating view %s...", k)
                del ctx.docs[k]
        else:
            ctx.note("Adding view %s...", k)
        if k not in ctx.docs:
            ctx.docs[k] = v


def cmd__couch_list(g):
    global ctx
    for ls in ctx.docs.view('bookmarks/list'):
        print(ls.id, ls.value)


def cmd__couch_add(Locator, TITLE, TAGS, g):
    """
    Add record directly to Couch. NOTE: should be using SQL API instead.
    """
    global ctx
    #[Locator] = {
    #  'type': 'bookmark',
    #  'href': Locator,
    #  'tags': TAGS
    #}
    assert isinstance(TAGS, list), TAGS
    bm = bookmark.Bookmark(id=Bookmark.keyid(Locator), href=Locator, tag_list=TAGS)
    bm.store(ctx.docs)


def cmd__sql_couch(g):

    """
    Update SQL DB Bookmark records from CouchDB.
    """

    global ctx
    total_docs = len(ctx.docs)
    i, c = 0, 0

    sa = Bookmark.get_session(g.session_name, g.dbref)
    for idref in ctx.docs:
        bmdoc = bookmark.Bookmark.load(ctx.docs, idref)
        zope.interface.classImplements(bmdoc.__class__, taxus.iface.IPyDict)
        i += 1
        ctx.note("Processing %i of %i", i, total_docs, num=i)

        lctr = Locator.fetch((Locator.ref == bmdoc.href,), exists=False)
        if not lctr:
            lctr = Locator.forge(bmdoc, g, sa=sa)

        bm = Bookmark.fetch((Bookmark.location == lctr,), exists=False)
        if not bm:
            bm = Bookmark.fetch((Bookmark.name == bmdoc.name,), exists=False)
            if bm:
                ctx.note("Name already exists for other location: %r at %r vs %r",
                        bmdoc.name, bmdoc.href, bmdoc.href )
                continue
            bm = Bookmark.forge(dict(location=lctr, **bmdoc), g, sa=sa)

        if not bm.update_from(bmdoc, location=lctr):
            if g.verbose > 2:
                ctx.note("No-op: %s", bmdoc.href)
            continue

        c += 1
        if not g.dry_run:
            sa.add(bm)
        if not g.quiet:
            ctx.note(bmdoc.href)

        if g.auto_commit and c and c % g.auto_commit == 0:
            if g.verbose > 1:
                ctx.note("Auto-commit at %i of %i", c, total_docs)
            sa.commit()

    if g.commit:
        sa.commit()


def cmd__couch_sql(NAME, opts, g):

    """
    Update CouchDB bookmark-type documents from SQL.
    """

    global ctx
    total_docs = len(ctx.docs)
    c, i = 0, 0

    # Get records to sync
    rs = ctx.get_records(Bookmark, name=NAME)
    if not rs:
        log.stdout("{yellow}Nothing found{default}")
        if g.strict:
            return 1
        return
    total_records = len(rs)
    ctx.note('Going to sync %i SQL records to %s...', total_records, ctx.couch[1])

    n, u, e = 0, 0, 0
    for r in rs:
        d = r.to_doc()
        i += 1
        _id = d.id

        map_id = d.href in ctx.docs
        if map_id:
            e += 1
            log.stderr("HREF %s", d.href)
            continue

        if _id not in ctx.docs:

            # New entry
            if not g.dry_run:
                d.store(ctx.docs)
            n += 1
            ctx.note('new %s', d.href)

        else:
            bm = bookmark.Bookmark.load(ctx.docs, _id)
            updated = False

            # NOTE: not doing anything else than bookmarks
            if bm.type != 'bookmark':
                log.stderr((
                    "Document {0} exists but is not of required type: {1}".format(
                    href, bm['type'])))
                continue

            # We can stop right there.
            if r.deleted:
                if bm.deleted:
                    continue
                bm.deleted = true
                bm.date_deleted = r.date_deleted
                # Soft delete, for archival/cleanup by someone else.
                continue

            # Check on update time to things speed up
            if g.clear_unknown_keys:
                c_dt = iso8601_datetime_format(bm.date_updated)
                if c_dt >= r.date_updated:
                    continue

            # Delete missing keys
            #if g.clear_unknown_keys:
            #    for k in bm.keys():
            #        if k in [ '_rev', '_id', 'type' ]:
            #            continue
            #        if k not in d:
            #            del bm[k]
            #            updated = True

            #if r.update_from(bm)
            #raise NotImplementedError
            # Set new or changed values
            for k in d.keys():
              if k not in bm or bm[k] != d[k]:
                  print(k, d[k], bm[k])
                  bm[k] = d[k]
                  updated = True

            if updated:
                # XXX: should I take now? rather not increment on non-descr changes
                bm['date_updated'] = r.date_updated
                if not g.dry_run:
                    bm.store(ctx.docs)
                u += 1
                if g.verbose:
                    print('updated %s' % href)

        if u:
            ctx.note("Updated doc-from-record %i, at %i from %i...", u, i, total_records, num=u)
        elif i:
            ctx.note("No doc-from-record changes at %i from %i...", i, total_records, num=i)

    ctx.note('%i new', n)
    ctx.note('%i updated', u)


def cmd__couch_update(g):

    """
    Update couchdb, preping data and fixing common errors before doing actual
    syncs. Fixes are controlled through flags.

    Unless no-db is on, an initial second run is done using all records from
    SQL. This allows to fix records using data from SQL.
    """

    global ctx
    total_docs = len(ctx.docs)
    # doc num, record num, updated from SQL, updated, skip
    d, i, c, u, e = 0, 0, 0, 0, 0

    if not g.no_db:
        # Starting with records from SQL, check every one with couch
        rs = ctx.get_records(Bookmark)
        if not rs:
            log.stdout("{yellow}Nothing found{default}")
            if g.strict:
                return 1
            return
        total_records = len(rs)
        ctx.note('Going to sync %i SQL records to %s...', total_records, ctx.couch[1])

        for r in rs:
            i += 1

            ### Fix document, or skip further updates by continueing to next doc

            # ID rename cleanup
            if g.update_hrefids:
                map_id = r.href in ctx.docs
                if map_id:
                    u += 1
                    doc = r.to_doc()
                    _id = doc.id
                    if not g.dry_run:
                        del ctx.docs[doc.href]
                        assert doc.href not in ctx.docs, doc.href
                        doc.store(ctx.docs)
                    log.stderr("Renamed href at %i to %s", i, _id)
                    continue

            if g.update_tagstype:
                _id = Bookmark.keyid(r.href)
                doc = ctx.docs[_id]
                if 'tags' in doc and isinstance(doc['tags'], list):
                    tags_split_from_string_error = None
                    for t in doc['tags']:
                        if len(t) == 1:
                            tags_split_from_string_error = True
                        if len(t) != 1:
                            tags_split_from_string_error = False
                    if tags_split_from_string_error:
                        u += 1
                        tags = "".join(doc['tags'])
                        doc['tag_list'] = tags.split(', ')
                        del doc['tags']
                        ctx.docs[doc.id] = doc

                elif 'tags' in doc:
                    u += 1
                    tags = doc['tags']
                    assert isinstance(tags, basestring), tags
                    assert ', ' in tags, tags
                    doc['tag_list'] = tags.split(', ')
                    del doc['tags']
                    ctx.docs[doc.id] = doc

            # TODO: other generic SQL-to-Couch updates here
            if u:
                ctx.note("Updated doc-from-record %i, at %i from %i...", u, i, total_records, num=u)
            elif i:
                ctx.note("No doc-from-record changes at %i from %i...", i, total_records, num=i)

    if c:
        ctx.note("Updated %i from %i", c, total_records)
    else:
        ctx.note("Nothing to do for %i SQL records", total_records)


    # Now loop over ID's from database again
    log.std("Checking %i docs..", total_docs)
    for idref in ctx.docs:
        d += 1
        doc = ctx.docs[idref]

        ### Fix document, or skip further updates by continueing to next doc


        # ID rename cleanup
        if idref == doc['href']:
            if not g.update_hrefids:
                e += 1
                continue
            c += 1
            bm = bookmark.Bookmark.load(ctx.docs, idref)
            bm.id = bookmark.Bookmark.key(bm)
            if not g.dry_run:
                bm.store(ctx.docs)
        assert not doc['href'] in ctx.docs, doc['href']


        # Migrate tags
        if 'tags' in doc:
            if not g.update_tagstype:
                e += 1
                continue
            c += 1
            bm = bookmark.Bookmark.load(ctx.docs, idref)

            if g.verbose > 1:
                print(idref, doc['href'], bm.date_added )

            if isinstance(doc['tags'], list):
                bm.tag_list = bm.tags
                assert isinstance(bm.tags, list)

            else:
                assert ', ' in bm.tags
                bm.tag_list = bm.tags.split(', ')

            del bm['tags']
            if not g.dry_run:
                #del ctx.docs[idref]
                bm.store(ctx.docs)


        if c:
            ctx.note("Updated %i, at %i from %i...", d, i, total_docs, num=c)
        else:
            ctx.note("Nothing to do at %i from %i...", i, total_docs, num=i)

    if c:
        ctx.note("Updated %i from %i", d, total_docs)
    else:
        ctx.note("Nothing to do for %i documents", total_docs)


"""
TODO: sync shaarli either from SQL or couch.

Also google/firefox bookmarks, chrome outliner.
"""

from shaarli_client.client import ShaarliV1Client, InvalidEndpointParameters


def cmd__shaarli_update(g):
    """
    TODO: Update SQL DB Bookmark records from Shaarli.
    """

def cmd__shaarli_sync(NAME, opts, g):
    """
    TODO: Update Shaarli bookmark-type documents from SQL.
    """


### Transform cmd__ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd__')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug,
        info = db_sa.cmd_info,
        init = db_sa.cmd_init,
        clear = db_sa.cmd_reset
))


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    ctx.settings.update(opts.flags)
    opts.flags.update(ctx.settings)
    opts.flags.update(dict(
        commit = not opts.flags.no_commit and not opts.flags.dry_run,
        verbose = opts.flags.quiet and opts.flags.verbose or 1,
    ))
    if not opts.flags.interactive:
        if os.isatty(sys.stdout.fileno()) and os.isatty(sys.stdout.fileno()):
            opts.flags.interactive = True
    opts.flags.update(dict(
        partial_match = not opts.flags.exact_match,
        auto_commit = not opts.flags.no_commit and opts.flags.auto_commit,
        dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    ))
    if opts.flags.interval:
        opts.flags.interval = int(opts.flags.interval)
    if opts.flags.auto_commit:
        opts.flags.auto_commit = int(opts.flags.auto_commit)
    return init

def main(opts):

    """
    Execute using docopt-mpe options.
    """
    global ctx, commands

    ws = Homedir.require()
    ws.yamldoc('bmsync', defaults=dict(
            last_sync=None
        ))
    ctx.ws = ws
    ctx.settings = settings = opts.flags
    ctx.init()
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'bookmarks.mpe/%s' % __version__


if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf-8')
    usage = __description__ +'\n\n'+ __short_description__ +'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'BM_DB', __db__ ),
        ( 'COUCH_DB', __couch__ ) )

    db_sa.schema = sys.modules['__main__']
    db_sa.metadata = SqlBase.metadata

    opts = libcmd_docopt.get_opts(usage,
            version=get_version(), defaults=defaults)
    # TODO: mask secrets
    #log.std("Connecting to %s", opts.flags.dbref)
    #log.std("Connecting to %s", opts.flags.couch)
    sys.exit(main(opts))
