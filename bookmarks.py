#!/usr/bin/env python
"""
:created: 2013-12-30

- Import old bookmarks from JSON, XML.

::

   Node<INode>
    * id_id:Integer<PrimaryKey>
    * ntype:String<50,NotNull,Polymorphic>
    * name:String<255,Null>
    * date_added:DateTime<Index,NotNull>
     A
     |
     .__,
     |   |
     |  Resource
     |   * status:Status
     |   * location:Locator
     |   * last_access:DateTime
     |   * allow:String
     |    
     .__, 
         |
        Bookmark
         * ref:Locator
         * extended:Text<64k>
         * public:Boolean
         * tags:Text<10k>

         * group:Bookmark<ForeignKey,Null> Grouped Mixin?
     |
    GroupNode
     * nodes:relationship

"""
from datetime import datetime
import os
import hashlib

import zope.interface
import zope.component
#from zope.component import \
#        getGlobalSiteManager, \
#        getUtility, queryUtility, createObject

import log
import libcmd
import res.iface
import res.js
import res.bm
import taxus.model
import taxus.net
from taxus.core import GroupNode
from taxus.checksum import MD5Digest
from taxus.net import Locator
from taxus.model import Bookmark
from txs import TaxusFe




class bookmarks(TaxusFe):

    #zope.interface.implements(res.iface.ISimpleCommand)

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DEFAULT_CONFIG_KEY = 'bm'

    #TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + ['']
    DEFAULT_ACTION = 'stats'

    DEPENDS = {
            'stats': ['txs_session'],
            'list': ['txs_session'],
            'add': ['txs_session'],
            'add_lctr': ['txs_session'],
            'list_lctr': ['txs_session'],
            'add_lctr_ref_md5': ['txs_session'],
            'add_ref_md5': ['txs_session'],
            'moz_js_import': ['txs_session'],
            'moz_js_group_import': ['txs_session'],
            'moz_ht_import': ['txs_session'],
            'dlcs_post_import': ['txs_session'],
            'export': ['txs_session']
        }

    @classmethod
    def get_optspec(Klass, inherit):

        """
        Return tuples with optparse command-line argument specification.
        """

        return (
            # actions
                (('-s', '--stats',), libcmd.cmddict()),
                (('-l', '--list',), libcmd.cmddict()),
                (('-a', '--add',), libcmd.cmddict()),
                (('--list-lctr',), libcmd.cmddict()),

                (('--moz-js-import',), libcmd.cmddict()),
                (('--dlcs-post-import',), libcmd.cmddict()),

                (('--export',), libcmd.cmddict(help="TODO: bm export")),

                (('--moz-js-group-import',), libcmd.cmddict()),

                (('--add-lctrs',), libcmd.cmddict(
                    help="Add locator records for given URL's.")),
                (('--add-ref-md5',), libcmd.cmddict(
                    help="Add MD5-refs missing (on all locators). ")),

            # params
                (('--public',), dict( action='store_true', default=False )),
                (('--name',), dict( default=None, type="str" )),
                (('--href',), dict( default=None, type="str" )),
                (('--ext',), dict( default=None, type="str" )),
                (('--tags',), dict( default=None, type="str" )),
                (('--ref-md5',), dict( action='store_true',
                    default=False, help="Calculate MD5 for new locators. " )),

            )

    def stats(self, opts=None, sa=None):

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
            sa.commit()
            if opts.ref_md5:
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
                if name != bm.name:
                    bm.name = name
                if lctr != bm.ref:
                    bm.ref = lctr
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
                    log.err("Duplicate name %s", bm)
                    bm.name = "%s (copy)" % name
                else:
                    bm = Bookmark(
                            name=name,
                            ref=lctr,
                            extended=ext,
                            public=public,
                            tags=tags,
                            date_added=datetime.now()
                        )
            assert bm.ref
            yield dict( bm=bm )
            sa.add(bm)
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
                print list(self.add(sa=sa, 
                    href=node['uri'], 
                    name=node['title'], 
                    ext=descr and descr.pop() or None,
                    opts=opts)).pop()

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
                    self.txs_add_group( node['title'], parent['title'],
                            sa=sa, opts=opts )
                else:
                    self.txs_add_group( node['title'], None, 
                            sa=sa, opts=opts )

            print 'Roots' 
            for root in roots:
                print root['id'], root['title']

    def dlcs_post_import(self, opts=None, sa=None, *paths):
        from pydelicious import dlcs_parse_xml
        for p in paths:
            data = dlcs_parse_xml(open(p).read())
            for post in data['posts']:
                #list(self.assert_locator(sa=sa, href=post['href'], opts=opts))
                bm = list(self.add( sa=sa, 
                    href=post['href'], 
                    name=post['description'], 
                    ext=post['extended'], 
                    tags=post['tag'],
                    opts=opts)).pop()
                tags = [ GroupNode.find(( GroupNode.name == t, )) 
                        for t in post['tag'].split(' ') ]
                for tag in tags:
                    if not tag:
                        continue
                    tag.subnodes.append( bm )

    def export(self, opts=None, sa=None, *paths):
        pass

if __name__ == '__main__':
    bookmarks.main()

