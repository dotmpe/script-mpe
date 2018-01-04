"""
TODO: cleanup
"""
import os

from wheezy.template.engine import Engine
from wheezy.template.ext.core import CoreExtension
from wheezy.template.loader import FileLoader
import zope.interface
from zope.interface import implements

from script_mpe.lib import cn
#import res.iface
from script_mpe.taxus import iface
#from . import iface
#import taxus.iface


### User view/Debug serializers

class Formatter(object):
    def __init__(self, name):
        self.name = name

class Formatters(object):
    names = {}
    types = {}


class PrintedRecordMixin(object):

    _formatter = None
    @classmethod
    def get_formatter(self):
        return self._formatter
    @classmethod
    def set_formatter(self, formatter):
        assert formatter.name and formatter.format
        self._formatter = formatter
        return self._formatter
    formatter = property(get_formatter, set_formatter)

    def get_format_name(self):
        if self._formatter:
            return self._formatter.name
    def set_format_name(self, name):
        assert name in Formatters.names
        self._formatter = Formatters.names[name](name)
        return self._formatter
    record_format = property(get_format_name, set_format_name)

#    def __call__(cls, *args, **kwds):
#        print 'rec mixin call', args
#        super(PrintedRecordMixin, cls).__call__(cls, *args, **kwds)
#        return cls
#
#    def __init__(self, *args, **kwds):
#        print 'rec mixin init', args
#        if 'formatter' in kwds:
#            self.formatter = kwds['formatter']
#            del kwds['formatter']
#        elif 'record_format' in kwds:
#            self.record_format = kwds['record_format']
#            del kwds['record_format']
#        else:
#            self.record_format = 'default'
#        print self.formatter, self.record_format
#        super(PrintedRecordMixin, self).__init__(self, *args, **kwds)

    def __repr__(self):
        if not self.formatter:
            name = cn(self)
            if self.__class__ in Formatters.types:
                self.formatter = Formatters.types[self.__class__]('repr_'+name)
            else:
                return "<Static %s at %s>" % (name, id(self))
        return self.formatter.format(self)


### Register some formatters

class RecordRepr(Formatter):
    def format(self, record):
        name = cn(record)
        return "<%s Record %i at %s>" % (name, record.id, id(record))

Formatters.names['default'] = RecordRepr


class Format2(Formatter):
    def format(self, record):
        name = cn(record)
        return "<%s #%i: \"%s\">" % (name, record.id, record.name)

Formatters.names['default'] = Format2


class RecordFields(Formatter):
    def format(self, record):
        fields = ["%s: %s" % (k.key, getattr(record, k.key)) for k in record.__mapper__.iterate_properties]
        name = cn(record)
        return "%s(%s)" % (name, ', '.join(fields))

Formatters.names['identity'] = RecordFields



# XXX moved from taxus.iface
class PrimitiveFormatter(object):
    implements(iface.IFormatted)

    __used_for__ = iface.Node

    def __init__(self, adaptee):
        self.adaptee = adaptee

    def toString(self):
        if isinstance(self.adaptee, str) or isinstance(self.adaptee, str):
            return self.adaptee
        else:
            return str(self.adaptee)

    def __str__(self, indent=0):
        return str(self.adaptee)

    def __unicode__(self, indent=0):
        return str(self.adaptee)


class IDFormatter(object):
    implements(iface.IFormatted)

    __used_for__ = iface.IID

    def __init__(self, adaptee):
        self.adaptee = adaptee

    def __str__(self, indent=0):
        ad = self.adaptee
        import taxus
        if hasattr(ad, 'name'):
            return "<urn:com.dotmpe:%s>"%str(ad.name)
        elif isinstance(ad, taxus.Locator):
            return "<%s>"%(ad.ref)


class NodeFormatter(object):
    implements(iface.IFormatted)

    __used_for__ = iface.Node

    def __init__(self, adaptee):
        self.adaptee = adaptee

    def __str__(self, indent=0):
        ad = self.adaptee
        indentstr = "".join('  ' * indent)
        fields = [
            indentstr+"%s: %s" % (k.key, iface.IFormatted(getattr(ad,
                k.key)).__str__(indent+1))
            #"%s: %s" % (k.key, getattr(ad, k.key))
            for k in ad.__mapper__.iterate_properties
            if not k.key.endswith('id')]
        #header = "%s <%s>" % ( cn(ad), ad.id )
        header = "Node <%s>" % ( ad.id ,)
        return "[%s\n\t%s]" % (header, '\n\t'.join(fields))


class NodeSetFormatter(object):
    implements(iface.IFormatted)

    __used_for__ = iface.INodeSet

    def __init__(self, adaptee):
        self.adaptee = adaptee

    def __str__(self, indent=0):
        strbuf = ""
        for node in self.adaptee.nodes:
            strbuf += iface.IFormatted(node).__str__(indent+1) + '\n'
        return strbuf


class OutputFormatter(object):
    implements(iface.IFormatted)

    __used_for__ = iface.INodeSet

    def __init__(self, adaptee):
        self.adaptee = adaptee



tpl_dir = os.path.join( os.path.dirname(__file__), 'tpl' )

def get_template(name):
    engine = Engine( loader=FileLoader([tpl_dir]), extensions=[ CoreExtension() ] )
    return engine.get_template(name)


def format_args(args):
    args = list(args)
    for i, a in enumerate(args):
        #if isinstance(a, (int,float,str,unicode)):
        type_ = type(a)
        if type_.__name__ in __builtins__:
            pass
        else:
            interfaces = list(zope.interface.providedBy(a).interfaces())
            if iface.IPrimitive in interfaces:
                args[i] = iface.IFormatted(a).toString()
            else:
                args[i] = str(a)
    return args
