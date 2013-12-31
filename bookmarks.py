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
import res.bm
import taxus.model
import taxus.net
from txs import TaxusFe




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

        mozbm = res.bm.MozJSONExport()

        for a in args:
            for r in mozbm.read_bm(a):
                
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
#                continue
                print '+'
                # TODO: next store all groups, clean up MozJSONExport a bit maybe

                sa.add( lctr )
                sa.commit()

        #nodetree = zope.component.getUtility(res.iface.IDir).tree( path, opts )
        #print nodetree


if __name__ == '__main__':
    bookmarks.main()

