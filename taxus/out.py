"""
TODO: cleanup
"""
from script_mpe.lib import cn

from zope.interface import implements

#import res.iface
import taxus.iface
from taxus.iface import IFormatted


### User view/Debug serializers

class Formatter(object):
    def __init__(self, name):
        #print 'new', name
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
    """
    Adapter
    """
    implements(IFormatted)
    __used_for__ = taxus.iface.Node

    def __init__(self, context):
        self.context = context

    def toString(self):
        if isinstance(self.context, unicode) or isinstance(self.context, str):
            return self.context
        else:
            return str(self.context)

    def __str__(self, indent=0):
        return str(self.context)

    def __unicode__(self, indent=0):
        return unicode(self.context)


class IDFormatter(object):
    """
    Adapter
    """
    implements(IFormatted)
    __used_for__ = taxus.iface.IID

    def __init__(self, context):
        self.context = context

    def __str__(self, indent=0):
        ctx = self.context
        import taxus
        if hasattr(ctx, 'name'):
            return "<urn:com.dotmpe:%s>"%str(ctx.name)
        elif isinstance(ctx, taxus.Locator):
            return "<%s>"%(ctx.ref)


class NodeFormatter(object):
    """
    Adapter
    """
    implements(IFormatted)
    __used_for__ = taxus.iface.Node

    def __init__(self, context):
        self.context = context

    def __str__(self, indent=0):
        ctx = self.context
        indentstr = "".join('  ' * indent)
        fields = [
            indentstr+"%s: %s" % (k.key, IFormatted(getattr(ctx,
                k.key)).__str__(indent+1)) 
            #"%s: %s" % (k.key, getattr(ctx, k.key)) 
            for k in ctx.__mapper__.iterate_properties
            if not k.key.endswith('id')]
        #header = "%s <%s>" % ( cn(ctx), ctx.id )
        header = "Node <%s>" % ( ctx.id ,)
        return "[%s\n\t%s]" % (header, '\n\t'.join(fields))


class NodeSetFormatter(object):
    """
    Adapter.
    """
    implements(IFormatted)

    __used_for__ = taxus.iface.INodeSet

    def __init__(self, context):
        self.context = context
    def __str__(self, indent=0):
        strbuf = ""
        for node in self.context.nodes:
            strbuf += IFormatted(node).__str__(indent+1) + '\n'
        return strbuf

