#!/usr/bin/env python
"""
:created: 2013-12-30

- Import old bookmarks from JSON, XML.

::

    <tag>:GroupNode
        *<bm>:Bookmark

    Bookmark

:updated: 2014-08-26
"""
__description__ = "bookmarks - "
__version__ = '0.0.0'
__db__ = '~/.bookmarks.sqlite'
__usage__ = """
Usage:
  bookmarks.py [options] dlcs (parse|import FILE|export)
  bookmarks.py [options] chrome (all|groups)
  bookmarks.py [options] stats
  bookmarks.py [options] (tag|href|domain) [NAME]
  bookmarks.py -h|--help
  bookmarks.py --version

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
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
    -v            Increase verbosity.

Other flags:
    -h --help     Show this usage description. 
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).


"""
from datetime import datetime
import os
import re
import hashlib
from urlparse import urlparse

#import zope.interface
#import zope.component
from pydelicious import dlcs_parse_xml

import log
import confparse
import util
import libcmd
import rsr
import taxus.iface
import res.iface
import res.js
import res.bm
from res import Volumedir
from taxus import init as model
from taxus.init import SqlBase, get_session
from taxus.core import Node, Name, Tag
from taxus.net import Locator, Domain

models = [Locator, Tag, Domain ]

#import bookmarks_model as model
#from bookmarks_model import Locator, Bookmark




# were all SQL schema is kept. bound to engine on get_session
SqlBase = model.SqlBase


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

    def stats(self, prog=None, opts=None, sa=None):
        assert sa, (opts, sa)
        urls = sa.query(Locator).count()
        log.note("Number of URLs: %s", urls)
        bms = sa.query(Bookmark).count()
        log.note("Number of bookmarks: %s", bms)
        for lctr in sa.query(Locator).filter(Locator.global_id==None).all():
            lctr.delete()
            log.note("Deleted Locator without global_id %s", lctr)
        for bm in sa.query(Bookmark).filter(Bookmark.ref_id==None).all():
            bm.delete()
            log.note("Deleted bookmark without ref %s", bm)

    def list(self, sa=None):
        bms = sa.query(Bookmark).all()
        fields = 'bm_id', 'name', 'public', 'date_added', 'deleted', 'ref', 'tags', 'extended'
        if not bms:
            log.warn("No entries")
        else:
            print '#', ', '.join(fields)
            for bm in bms:
                for f in fields:
                    print getattr(bm, f),
                print

    def assert_locator(self, sa=None, href=None, opts=None):
        lctr = Locator.find((Locator.global_id==href,), sa=sa)
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
            bm = Bookmark.find((Bookmark.ref==lctr,), sa=sa)
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
                bm = Bookmark.find((Bookmark.name==name,), sa=sa)
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

    def list_lctr(self, sa=None):
        lctrs = sa.query(Locator).all()
        # XXX idem as erlier, some mappings in adapter
        fields = 'lctr_id', 'global_id', 'ref_md5', 'date_added', 'deleted', 'ref'
        # XXX should need a table formatter here
        print '#', ', '.join(fields)
        for lctr in lctrs:
            for f in fields:
                print getattr(lctr, f),
            print

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
                md5 = MD5Digest.find(( MD5Digest.digest == ref_md5, ))
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
            print 'Groups' 
            for nid, node in nodes.items():
                #print repr(node['title']),
                if 'parent' in node:
                    parent = nodes[node['parent']]
                    self.rsr_add_group( node['title'], parent['title'],
                            sa=sa, opts=opts )
                else:
                    self.rsr_add_group( node['title'], None, 
                            sa=sa, opts=opts )
            print 'Roots' 
            for root in roots:
                print root['id'], root['title']

    def dlcs_post_read(self, p):
        from pydelicious import dlcs_parse_xml
        data = dlcs_parse_xml(open(p).read())
        for post in data['posts']:
            yield post
    
    def dlcs_post_test(self, p):
        bm = self.execute( 'dlcs_post_read', dict( p=p) , 'all-key:href' )
        print p, len(bm)

    def dlcs_post_test2(self, p):
        pass

    def dlcs_post_import(self, prog=None, opts=None, sa=None, *paths):
        from pydelicious import dlcs_parse_xml
        GroupNode = res.iface.IGroupNode(prog)
        # print list of existing later
        grouptags = []
        for p in paths:
            for post in self.execute( 'dlcs_post_read', dict( p=p), 'gen-all-key:href' ):
                pass

            data = dlcs_parse_xml(open(p).read())
            for post in data['posts']:
                lctrs = [ d['lctr'] for d in self.assert_locator(
                            sa=sa, href=post['href'], opts=opts) ]
                self.execute( 'assert_locator', dict(href=post['href']) )
                if not lctrs:
                    continue
                bm = self.execute( 'assert_locator', bm_dict, 'first-key:bm' )

                lctr = lctrs.pop()
                bms = [ d['bm'] for d in self.add( sa=sa, 
                    href=post['href'], 
                    name=post['description'], 
                    ext=post['extended'], 
                    tags=post['tag'],
                    opts=opts) ]
                if not bms:
                    continue
                bm = bms.pop()
                tags = [ GroupNode.find(( GroupNode.name == t, ), sa=sa ) 
                        for t in post['tag'].split(' ') ]
                [ grouptags.append(t) for t in tags if t ]
                for tag in tags:
                    if not tag:
                        continue
                    tag.subnodes.append( bm )
                    sa.add( tag )
        for tag in grouptags:
            print 'Tag', tag.name
            for node in tag.subnodes:
                print node.node_id, node.name,
                if hasattr(node, 'ref'):
                    print node.ref
                else:
                    print
        
        if opts.rsr_auto_commit:
            sa.commit()

    def export(self, opts=None, sa=None, *paths):
        pass



def cmd_dlcs_import(opts, settings):
    """
    TODO: built into generic import/export (ie. complete set)  so heuristics can
        update all stats each import.. or find some way to fragment dataset.
    """
    importFile = opts.args.FILE
    data = dlcs_parse_xml(open(importFile).read())
    sa = Locator.get_session('default', opts.flags.dbref)
    #sa = model.get_session(opts.flags.dbref, metadata=SqlBase.metadata)
    tags_stat = {}
    domains_stat = {}
    # first pass: validate, track stats and create Locator records where missing
    for post in data['posts']:
        href = post['href']
        lctr = Locator.find((Locator.ref == href,))
# validate URL
        url = urlparse(href)
        domain = url[1]
        if not domain:
            log.std("Ignored non-net URIRef: %s", href)
            continue
        assert re.match('[a-z0-9]+(\.[a-z0-9]+)*', domain), domain
# get/init Locator
        if not lctr:
            lctr = Locator(
                    global_id=href,
                    ref=href)
            lctr.init_defaults()
            log.std("new: %s", lctr)
            sa.add(lctr)
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
            domain_record = Domain.find((Domain.name == domain,))
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
            tags += 1
            t = Tag.find((Tag.name == tag,))
            if not t:
                t = Tag(name=tag)
                t.init_defaults()
                log.std("new: %s", t)
                sa.add(t)
            # store frequencies
            # TODO tags_freq
    log.std("Checked %i tags", len(tags_stat))
    log.std("Tracking %i tags", tags)
    sa.commit()
    return
    for post in data['posts']:
        lctr = Locator.find((Locator.ref == post['href'],))
        for tag in post['tag'].split(' '):
            if tags_stat[tag] > x:
                x = tags_stat[x]
            if tag in tags_stat:
                tags_stat[tag] += 1
            else:
                tags_stat[tag] = 1

def cmd_chrome_all(settings):
    """
    Bookmarks and groups from Chrome JSON.
    """
    fn = os.path.expanduser(
            '~/Library/Application Support/Google/Chrome/Default/Bookmarks')
    bms = confparse.Values(res.js.load(open(fn)))
    print 'checksum', bms.checksum
    print 'version', bms.version
    bookmark_bar = confparse.Values(bms.roots['bookmark_bar'])
    def p(bm, i=1):
        print i*'  ', '-', '`'+bm.name, 'url' in bm and '<'+bm.url+'>`_' or '`'
        if 'children' in bm and bm.children:
            for sb in bm.children:
                p(confparse.Values(sb), i+1)
    p(bookmark_bar)
    other = confparse.Values(bms.roots['other'])
    p(other)

g_cnt = 0
def cmd_chrome_groups(settings):
    """
    Groups from Chrome bookmarks
    """
    fn = os.path.expanduser(
            '~/Library/Application Support/Google/Chrome/Default/Bookmarks')
    bms = confparse.Values(res.js.load(open(fn)))
    bookmark_bar = confparse.Values(bms.roots['bookmark_bar'])

    def p(bm, i=1):
        global g_cnt
        if 'url' in bm:
            return
        g_cnt += 1
        print i*'  ', '-', '`'+bm.name
        if 'children' in bm and bm.children:
            for sb in bm.children:
                p(confparse.Values(sb), i+1)
    p(bookmark_bar)
    print 'Subtotal', g_cnt

    other = confparse.Values(bms.roots['other'])
    p(other)
    print 'Total', g_cnt

def cmd_stats(settings):
    sa = get_session(settings.dbref)
    for stat, label in (
                (sa.query(Locator).count(), "Number of URLs: %s"),
                #(sa.query(Bookmark).count(), "Number of bookmarks: %s"),
                (sa.query(Domain).count(), "Number of domains: %s"),
                (sa.query(Tag).count(), "Number of tags: %s"),
            ):
        log.std(label, stat)

def cmd_href(NAME, settings):
    sa = Locator.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Locator.search(ref=NAME)
    else:
        rs = Locator.all()
    if not rs:
        log.std("Nothing")
    for r in rs:
        print r.ref

def cmd_tag(NAME, settings):
    sa = Tag.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Tag.search(name=NAME)
    else:
        rs = Tag.all()
    if not rs:
        log.std("Nothing")
    for r in rs:
        print r.name

def cmd_domain(NAME, settings):
    sa = Domain.get_session(settings.session_name, settings.dbref)
    if NAME:
        rs = Domain.search(name=NAME)
    else:
        rs = Domain.all()
    if not rs:
        log.std("Nothing")
    for r in rs:
        print r.name

### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = util.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    return util.run_commands(commands, settings, opts)

def get_version():
    return 'bookmarks.mpe/%s' % __version__

if __name__ == '__main__':
    #bookmarks.main()
    import sys
    db = os.getenv( 'BOOKMARKS_DB', __db__ )
    vdir = Volumedir.find()
    print 'vdir', vdir
    usage = __usage__ % ( db, __version__ )
    opts = util.get_opts(__doc__ + usage, version=get_version())
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))

