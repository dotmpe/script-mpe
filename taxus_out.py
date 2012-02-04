"""
Output handling using Zope adapters.

TODO: create various output adapters for various formats 
"""
import zope.interface
from zope.interface.interface import adapter_hooks
from zope.interface.adapter import AdapterRegistry

import libcmd

registry = AdapterRegistry()

class IID(zope.interface.Interface): pass
class IPrimitive(zope.interface.Interface): pass
class INode(zope.interface.Interface): pass
class INodeSet(zope.interface.Interface):
    nodes = zope.interface.Attribute("The list of nodes. ")
class IFormatted(zope.interface.Interface): pass

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

    def __str__(self, indent=0):
        return str(self.context)

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
            for k in ctx.__mapper__.iterate_properties]
        header = "%s <%s" % ( cn(ctx), ctx.id )
        return "%s\n%s" % (header, '\n'.join(fields))


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
        libcmd.err("Could not adapt %s:%s > %s", object, adapted, provided)
    return adapter(object)

adapter_hooks.append(hook)

