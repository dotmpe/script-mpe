#!/usr/bin/env python
"""
:created: 2013-12-30
"""
import os

import zope

import log
import res
import taxus.model
import taxus.net
from txs import TaxusFe


class bookmarks(TaxusFe):

    zope.interface.implements(res.iface.ISimpleCommand)

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
                )

    def stats(self, opts=None, sa=None):

        ""
        # TODO: get store with metadir and show stats

        urls = sa.query(taxus.net.Locator).count()
        log.note("Number of URLs: %s", urls)
        bms = sa.query(taxus.model.Bookmark).count()
        log.note("Number of bookmarks: %s", bms)

    def bm_import(self, args=None, opts=None, sa=None):

        ""
      
        
        adapt
        createObject
        getUtility
        pass


if __name__ == '__main__':
    bookmarks.main()

