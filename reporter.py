"""
zope.interfaces based output components.
this is for adapting objects to CLI printouts, possibly simple reporting.
XXX: see log, taxus_out for older model.
"""
from __future__ import print_function
import sys
import zope.interface
#from zope.interface.interface import adapter_hooks
#from zope.interface.adapter import AdapterRegistry

from . import confparse
from . import taxus
from .taxus import iface
from .res import iface
from . import log



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


@zope.interface.implementer(taxus.iface.IReport)
class StageReport(AbstractReport):

    def __init__(self, meta):
        self.meta = meta

    @property
    def text(self):
        raise NotImplemented


class Reporter(object):

    """

    Facade to hold an aggregate of report objects,
    ie. lists of messages, tables, trees and other complex objects.

    TODO: write directly to an output adapter (for log, console, etc.)
    TODO: turn context into state. Allow to extend and update.
    TODO: some level of reference modelling is needed, ie. accumulate footnotes,
        references. or prologue. be prepared to deal with buffered, parallel
        streams that are muxdem'ed on resolve and/or finalize.
    TODO:
        Try to keep some standard handlers so output is rSt compatible,
        or allow some level of syntax or environment to switch output formats
        on resolve or in mid-stream.

    Some methods:
        low-level: write, writeln
        high-level:
            handlerType, handlerName:  sub, format, arg

            print_paragraph
                start_paragraph
                finish_paragraph
            print_section
                start_section
                    print_title
                finish_section
            print_list
                start_list
                print_item
                    start_item
                    finish_item
                finish_list
            print_usage

    Initial state:

    """

    def __init__(self, initial_state='rst', out=sys.stdout):
        self.data = {}
        self.out = out
        self.state = states.registry[initial_state]

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
            print("%s" % k)
            for k2 in self.data[k]:
                print("  "+self.titles[k2])
                for i in self.data[k][k2]:
                    print("      - " + ( self.tpls[k2] % i ))

    def ensure_blankline(self):
        pass
    def write(self, data):
        self.out.write(log.format_str(data))
    def writeln(self):
        print(log.format_str(data), file=self.out)

    def __getattr__(self, name):
        hType, hName = name.split('_', 1)

        print(hType, hName)

    def get_context_path(self):
        return 'rst', 'paragraph'

    # core handlers
    def finish(self):
        pass


# XXX: work in progress
#class TableReporter(object):
#
#    def __init__(self):
#        self.rowcols = {}
#        self.colheaders = []


class AbstractOutputState(object):

    """
    Baseclass for output states.
    Output states are started from a parent state, the context.

    The state registry tracks the new states that a state type may spawn.
    """

    def __init__(self, reporter, context):
        self.reporter = reporter
        self.context = context
    def start(self, *args, **params):
        pass
    def add(self, value):
        self.reporter.writeln(str(value))
    def finish(self):
        pass


class states(object):

    class AbstractTxt(AbstractOutputState): pass
    class TxtBlock(AbstractTxt):
        def start(self, *args, **params):
            pass
        def add(self, value):
            self.reporter.writeln(str(value))
        def finish(self):
            pass
    class TxtInline(AbstractTxt):
        def start(self):
            self.reporter.ensure_blankline()
        def add(self, value):
            self.reporter.write(str(value))
            self.reporter.write(' ')
        def finish(self):
            self.reporter.writeln()
            self.reporter.writeln()
    class TxtEmphasizeInline(TxtInline): pass
    class TxtStrongInline(TxtInline): pass
    class TxtReference(TxtInline): pass
    class TxtCite(TxtInline): pass
    class TxtLiteral(TxtInline): pass
    class TxtNameRef(TxtInline): pass
    class TxtTitle(TxtInline): pass
    class TxtList(TxtInline): pass
    class TxtItem(TxtInline): pass

    class RstOut(object):
        pass

    registry = {
            'txt': (TxtBlock, {
                'paragraph': (TxtInline, {
                    # inline styles
                    'emphasis': (TxtEmphasizeInline, {
                    }),
                    'strong': (TxtStrongInline, {
                    }),
                    #
                    'pull-out': (TxtStrongInline, {
                    }),
                    # inline roles
                    'reference': (TxtReference, {
                    }),
                    'cite': (TxtCite, {
                    }),
                    'literal': (TxtLiteral, {
                    }),
                    'name': (TxtNameRef, {
                    }),
                }),
                'section': (TxtBlock, {
                    'paragraph': (TxtInline, {
                    }),
                }),
                'list': (TxtList, {
                    'item': (TxtItem, {
                        'paragraph': (TxtInline, {
                        }),
                    }),
                }),
            }),
            'rst': RstOut
        }


class stdout(object):

    formatters = {
            }

    class register(object):
        """
        Add a new object formatter.
        Can support any context types it likes (but should fail explicitly),
        Reporter will gracefully recover for most standard contexts.
        """
        def __init__(self, *args, **kwds):
            #assert Klass.__name___ not in formatters
            self.Klasses = args
            if 'key' in kwds and kwds['key']:
                self.key = kwds['key']
            else:
                self.key = args[0].className()
            self.handler = None
            setattr(stdout, self.key, self)

        def __call__(self, *args):
            if not self.handler:
                self.handler = args[0]
            else:
                self.handler(*args)
