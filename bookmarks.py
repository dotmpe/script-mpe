#!/usr/bin/env python
"""
:created: 2013-12-30
"""
import os

import zope

import res
from txs import TaxusFe


# TODO see radical, basename-reg, mimereg, flesh out TaxusFe
class bookmarks(TaxusFe):

    zope.interface.implements(res.iface.ISimpleCommand)

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DEFAULT_CONFIG_KEY = 'bm'

    #TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + ['']
    DEFAULT_ACTION = 'stats'

    DEPENDS = {
            'stats': ['txs-session']
        }

    @classmethod
    def get_optspec(Klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
                )

    def stats(self, opts=None):
        ""
        # get store with metadir and show stats



if __name__ == '__main__':
    bookmarks.main()

