"""
Output handling using Zope adapters.

TODO: create various output adapters for various formats 
"""
#import sys, codecs, locale
#print locale.getpreferredencoding()
#print sys.stdout.encoding
#print str(sys.stdout.encoding)
#sys.stdout = codecs.getwriter('UTF-8')(sys.stdout);
#print str(sys.stdout.encoding)

import zope.interface
from zope.interface.interface import adapter_hooks
from zope.interface.adapter import AdapterRegistry

#import taxus
#import libcmd

registry = AdapterRegistry()

# generic types for stored object
class IID(zope.interface.Interface): pass
class IPrimitive(zope.interface.Interface): pass
class INode(zope.interface.Interface): pass
class INodeSet(zope.interface.Interface):
    nodes = zope.interface.Attribute("The list of nodes. ")

# output media types
class IFormatted(zope.interface.Interface): pass
# XXX: unused
class IInteractive(IFormatted): pass#zope.interface.Interface): pass

# on line (retrievable) and cachable types
class IResource(zope.interface.Interface): pass
class IPersisted(IResource): pass
"""
XXX: figure out interface methods/properties or related interfaces.

IResource may be interactive and/or multipart aggregate resources.
Ie. an IResource may consist of or contain other IResource instances, 
build dynamically during or for a communication session.

These are Variant resources meaning their format can change and their
content is a derivative; it may have other representations, and may be opaque,
or publicize an internal schema somehow.

Non-variant resources are fixed bytestreams of which only the envelope
changes (ie. the transmission encoding(s), parent archive or non-file storage 
location). These types may implement IPersisted.
"""

# /xxx

def cn(obj):
    return obj.__class__.__name__


class PrimitiveFormatter(object):
    """
    Adapter
    """
    zope.interface.implements(IFormatted)
    __used_for__ = INode

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
    zope.interface.implements(IFormatted)
    __used_for__ = IID

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
    zope.interface.implements(IFormatted)
    __used_for__ = INode

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
    Adapter
    """
    zope.interface.implements(IFormatted)
    __used_for__ = INodeSet
    def __init__(self, context):
        self.context = context
    def __str__(self, indent=0):
        strbuf = ""
        for node in self.context.nodes:
            strbuf += IFormatted(node).__str__(indent+1) + '\n'
        return strbuf

from datetime import datetime

zope.interface.classImplements(str, IPrimitive)
zope.interface.classImplements(unicode, IPrimitive)
zope.interface.classImplements(int, IPrimitive)
#zope.interface.classImplements(dict, IPrimitive)
zope.interface.classImplements(list, IPrimitive)

zope.interface.classImplements(datetime, IPrimitive)

registry.register([IID], IFormatted, '', IDFormatter)
registry.register([IPrimitive], IFormatted, '', PrimitiveFormatter)

registry.register([INodeSet], IFormatted, '', NodeSetFormatter)
registry.register([INode], IFormatted, '', NodeFormatter)

def hook(provided, object):
    if object == None:
        return PrimitiveFormatter(None)
    adapted = zope.interface.providedBy(object)
    #libcmd.err("Adapting %s:%s", object, adapted)
    adapter = registry.lookup1(
            adapted, provided, '')
    if not adapter:
        import sys
        #libcmd.err("Could not adapt %s:%s > %s", object, adapted, provided)
        print >>sys.stderr, "Could not adapt %s:%s > %s" %(object, adapted, provided)
    return adapter(object)

adapter_hooks.append(hook)

