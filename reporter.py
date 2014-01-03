"""
zope.interfaces based output components.
this is for adapting objects to CLI printouts, possibly simple reporting.
XXX: see log, taxus_out for older model.
"""
import zope.interface
#from zope.interface.interface import adapter_hooks
#from zope.interface.adapter import AdapterRegistry

import confparse
import taxus.iface
import res.iface
import log



class AbstractReport(object):

    def __init__(self):
        self.level = log.INFO
        self.formatting = 'flowed'
        self.line_width = 0
        self.line_width_preferred = 0

    @property
    def text(self):
        raise NotImplemented

    @property
    def ansi(self):
        return self.text()

class StageReport(AbstractReport):

    zope.interface.implements(taxus.iface.IReport)

    def __init__(self, meta):
        self.meta = meta

    @property
    def text(self):
        raise NotImplemented


class Reporter(object):

    """
    Facade to hold an aggregate of report objects,
    ie. lists of messages, tables, trees and other complex objects.
    """

    def __init__(self):
        self.data = {}

    def update(self, data):
        """
        Add data, object that implements IResult.
        """
        confparse.DictDeepUpdate.update(self.data, data)

    # Utils

    # XXX: cli output, ansi colours
    tpls = {
            'unknown': "%(c01)s%%s%(c17)s" % log.palette2,
            }
    titles = {
            'unknown': "%(c17)sUnknown%(c07)s" % log.palette2,
            }

    # Reporter

    def flush(self):
        for k in self.data:
            print "%s" % k
            for k2 in self.data[k]:
                print "  "+self.titles[k2] 
                for i in self.data[k][k2]:
                    print "      - " + ( self.tpls[k2] % i )

# XXX: work in progress
#class TableReporter(object):
#
#    def __init__(self):
#        self.rowcols = {}
#        self.colheaders = []

