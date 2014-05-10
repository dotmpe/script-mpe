"""
Interfaces 
Output handling using Zope adapters.
"""
#import sys, codecs, locale
#print locale.getpreferredencoding()
#print sys.stdout.encoding
#print str(sys.stdout.encoding)
#sys.stdout = codecs.getwriter('UTF-8')(sys.stdout);
#print str(sys.stdout.encoding)

import zope.interface
from zope.interface import Interface, Attribute, implements, \
        implementedBy, providedBy
from zope.interface.interface import adapter_hooks
from zope.interface.adapter import AdapterRegistry
from zope.component import \
        getGlobalSiteManager

from script_mpe.lib import cn
#import taxus
#import libcmd


gsm = getGlobalSiteManager()
registry = AdapterRegistry()


# generic types for stored object
class IID(Interface): pass
class IPrimitive(Interface): pass
class Node(Interface): pass
class INodeSet(Interface):
    nodes = Attribute("The list of nodes. ")

# output media types
class IFormatted(Interface):
    """
    The serialized representation of another object.
    """
#class ISerialized(IFormatted):
#    """
#    The formatted object of an ISerializable, which may be deserialized.
#    Otherwise use IFormatted.
#    """
# XXX: unused
#class IInteractive(IFormatted):
#    """
#    The interactive interface implicates that besides serialization,
#    there is an interactive action-response part to the representation.
#
#    The interaction usually consists of making choices or entering values.
#    Ofcourse the selection of sensible defaults makes for the best 
#    UX, but interaction is nevertheless not always avoidable.
#
#    This interface is used to declare wether a target requires some external
#    system or user interaction for successful completion, and to anticipate
#    the situation where such target is required. A common method is to 
#    load settings from the configuration, and let in this way personal
#    preference take out a lot of the interactive settings of a target.
#    """

# on line (retrievable) and cachable types
class IResource(Interface):
    """
    Something that is identified by a Universal Resource Indicator.

    Note the implication of RESTful architecture in the semantics (I'm not sure 
    how URN even fits into that?!).

    A Resource, in taxus/sqlalchemy, is split into Variant resources
    and Invariant resources. Invariants are those with an immutable bytestream
    representation of its entity (regardless of transport codecs).
    Variants are the abstract counterparts of invariants that have no single but 
    several or a multitude of bytestreams that in most cases are generated by a 
    server side script. In the case of RDF and other symbolic use of URIRefs, 
    there may be no IVariant or Invariant because the vendor does not publish
    anything at these URL's. Even though this is recommended practice.

    Generally when dealing with URL's, these are below 2000 characters for a
    good deal of the software. However no RFC has set a bound, other than that
    the server is responsible for the URL length [RFC 2616]. Generally the given
    bound is safe accross desktop and other modern web browsers. Because URL's
    may be far smaller or larger, a few classes of identifiers emerge.
    
    The smallest URL's fit in less than 20 bytes, it takes just 7 characters
    plus the hostname. For many URL shorteners, just over 20 bytes is enough to
    serve legions. Class A is anything up to 25 characters.

    Note that URL shortening may be beficial for high volume, it is a 
    flawed technical practice. It is suceptible to link-rot. The sites are
    fairly dumb, increasing spammer interest, adding to more link rot because
    of site shutdowns, etc.

    The largest URLs might be from systems with very big forms, but may also 
    be embedded scripts such as in the ``javascript:`` scheme. In bookmarklets,
    these easily reach thousands of characters for some modest but coherent 
    client functions.
    """

class IPersisted(IResource):
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


class IReportable(Interface):
    """
    Interface for reportable objects, adaptable to report instances.
    To use with libcmd and reporer.Reporter class.
    """

class IReport(Interface):
    """
    Interface for report instances.
    To use with libcmd and reporer.Reporter class.
    """
    text = Attribute("A text fragment (readonly). ")
    ansi = Attribute("An ANSI formatted variant of `text` (readonly).")
    level = Attribute("A level associated with the text fragment (readonly). ")

    formatting = Attribute("Preformatted, monospace text is 'static', or 'normal' for flowed. ")
    line_width = Attribute("If needed, indicate minimal line-width. ")
    line_width_preferred = Attribute("Optionally, indicate preferred line-width. ")

class IReporter(Interface):
    ""
    append = Attribute("method for adding subsequent IReportables to report")

class IResultAdapter(Interface): pass

class IRelationalModel(Interface): pass

class INode(IRelationalModel): pass
class IGroupNode(IRelationalModel): pass
class IMD5Digest(IRelationalModel): pass
class ILocator(IRelationalModel): pass
class IBookmark(IRelationalModel): pass

class IProgram(Interface): pass

def programModelResolver(*args):
    print 'programModelResolver', args

gsm.registerAdapter(
    programModelResolver, [IProgram], IRelationalModel, '')


def registerAdapter(adapterClass, sifaces=[], tiface=None):
    global registry
    if not sifaces:
        sifaces = [adapterClass.__used_for__]
        assert sifaces
    if not tiface:
        tiface = implementedBy(adapterClass).interfaces().next()
    registry.register(sifaces, tiface, '', adapterClass)

def hook( provided, o ):
    global registry
    if  o  == None:
        return PrimitiveFormatter(None)
    adapted = providedBy( o )
    #libcmd.err("Adapting %s:%s",  o , adapted)
    adapter = registry.lookup1(
            adapted, provided, '')
    if not adapter:
        import sys
        #libcmd.err("Could not adapt %s:%s > %s",  o , adapted, provided)
        print >>sys.stderr, "Could not adapt %s:%s > %s" %( o , adapted, provided)
    assert adapter, (provided, o)
    return adapter( o )

adapter_hooks.append(hook)

