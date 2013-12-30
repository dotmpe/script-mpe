#!/usr/bin/env python
"""
:created: 2013-12-30
"""
import os

import res
from txs import TaxusFe


# TODO see radical, basename-reg, mimereg, flesh out TaxusFe
class bookmarks(TaxusFe):

    zope.interface.implements(res.iface.ISimpleCommand)

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DEFAULT_CONFIG_KEY = NAME

    #TRANSIENT_OPTS = Taxus.TRANSIENT_OPTS + ['']
    DEFAULT_ACTION = 'tasks'

    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
                )


if __name__ == '__main__':
    bookmarks.main()

