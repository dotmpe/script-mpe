#!/usr/bin/env python
"""
:created: 2013-12-30

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

import zope.interface
import zope.component
#from zope.component import \
#        getGlobalSiteManager, \
#        getUtility, queryUtility, createObject

import log
import libcmd
import res.iface
import res.js
import taxus.model
import taxus.net
from txs import TaxusFe



def recursive_read(json, lvl=0):

    if 'id' in json and json['id']:
        if json['id'] == 1912:
            import sys
            sys.exit()

    #    print
    #    print ( '\t'*lvl ) + str(json['id'])
    #if 'title' in json and json['title']:
    #    print ( '\t'*lvl ) + json['title']
    if 'uri' in json and json['uri']:
        yield json['uri']
        #print ( '\t'*lvl ) + json['uri']

    if 'children' in json:
        for x in json['children']:
            for ref in recursive_read(x, lvl+1):
                yield ref


def read_bm(path):
    log.info("reading %s", path)
    data = open(path).read()
    json = res.js.loads(data)
        
    for ref in recursive_read(json):
        if ref.startswith('place:'): # mozilla things
            continue
        elif ref.startswith('chrome:') or ref.startswith('about:') \
            or ref.startswith('file:') \
            or ref.startswith('javascript:') \
            or ref.startswith('http:') or ref.startswith('https:'):
            yield ref
        else:
            assert False, ref


class bookmarks(TaxusFe):

    #zope.interface.implements(res.iface.ISimpleCommand)

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DEFAULT_CONFIG_KEY = 'bm'

    #TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + ['']
    DEFAULT_ACTION = 'stats'

    DEPENDS = {
            'stats': ['txs_session'],
            'bm_import': ['txs_session'],
            'bm_export': ['txs_session']
        }

    @classmethod
    def get_optspec(Klass, inherit):

        """
        Return tuples with optparse command-line argument specification.
        """

        return (
                (('--bm-import',), libcmd.cmddict()),
                (('--bm-export',), libcmd.cmddict()),
            )

    def stats(self, opts=None, sa=None):

        ""
        # TODO: get store with metadir and show stats

        assert sa, (opts, sa)
        urls = sa.query(taxus.net.Locator).count()
        log.note("Number of URLs: %s", urls)
        bms = sa.query(taxus.model.Bookmark).count()
        log.note("Number of bookmarks: %s", bms)

    def bm_import(self, args=None, opts=None, sa=None):

        ""

        for a in args:
            for r in read_bm(a):
                
                if len(r) > 255:
                    log.err("Reference too long: %s", r)
                    continue

                lctrs = sa.query(taxus.net.Locator)\
                        .filter(taxus.net.Locator.global_id == r)\
                        .all()
                if lctrs:
                    #print '.',
                    print r, lctrs
                    continue

                lctr = taxus.net.Locator( global_id=r,
                        date_added=datetime.now() )

                print 'New', lctr 
                continue
                print '+'

                sa.add( lctr )
                sa.commit()

        #nodetree = zope.component.getUtility(res.iface.IDir).tree( path, opts )
        #print nodetree


if __name__ == '__main__':
    bookmarks.main()

