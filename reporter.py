"""
zope.interfaces based output components.
this is for adapting objects to CLI printouts, possibly simple reporting.
XXX: see log, taxus_out for older model.
"""
import collections
import zope.interface
#from zope.interface.interface import adapter_hooks
#from zope.interface.adapter import AdapterRegistry

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

    zope.interface.implements(res.iface.IReport)

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
        self.__class__.deepupdate(self.data, data)

    # Utils

    @classmethod
    def deepupdate(Class, sub, data):
        for k, v in data.iteritems():
            if isinstance(v, collections.Mapping):
                r = Class.deepupdate(sub.get(k, {}), v)
                sub[k] = r
            elif isinstance(v, list):
                if k in sub:
                    assert isinstance(sub[k], list)
                else:
                    sub[k] = []
                sub[k].extend(v)
            else:
                sub[k] = data[k]
        return sub

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

