"""
Classes using primitive values and native structures.

TreeNode
    key
        Unique name or ID
    subnodes
        List of TreeNode instances; subnodes

    Besides key and subnodes, TreeNode supports others attributes.
    As long as these don't collide with TreeNodeDict (and Python dict).

"""
import zope
from zope.component import queryAdapter, getGlobalSiteManager

import log
import lib
from script_mpe.res import iface as res_iface
from script_mpe.taxus import iface


class TreeNodeDict(dict):

    """
    XXX: Normally TreeNodeDict contains one TreeNode, but the dict would allow
        for multiple branchings?
    XXX: would be nice to manage type for leafs somehow, perhaps using visitor
    """

    zope.interface.implements(res_iface.ITree)

    ATTR_PREFIX = '@'
    "static config for attribute prefix"

    def __init__(self, nameOrObject=None, parent=None, subnodes=[],
            attributes={}, attr_prefix=ATTR_PREFIX):
        dict.__init__(self)
        if not isinstance(nameOrObject, unicode):
            assert not isinstance(nameOrObject, str)
            self.__name__ = res_iface.IName(nameOrObject)
        else:
            self.__name__ = nameOrObject
        self[self.__name__] = subnodes
        if parent:
            self.__parent__ = parent
        self.__prefix__ = attr_prefix
        for name, value in attributes.items():
            setattr(self, name, value)

    def getkeys(self):
        """
        Besides attributes, there may be other items.
        Return those.
        """
        for key in self:
            # XXX: perhaps re-use QNames objects for regular attribute names
            #if not IAttribute.providedBy( key ):
            #    yield key
            if isinstance( key, basestring ):
                if not key.startswith(self.__prefix__):
                    yield key
            else:
                yield key.nodeid

    def getid(self):
        # FIXME: return first 'key'
        for key in self.getkeys():
            return key

    def getnodetype(self):
        # FIXME: return first 'key'
        for key in self.getkeys():
            return key.__class__

    def setid(self, name):
        oldkey = self.getid()
        val = self[oldkey]
        del self[oldkey]
        self[name] = val

    nodeid = property(getid, setid)
    "Node.nodid is a property or '@'-prefix attribute key. "

    def append(self, val):
        "Node().subnodes append"
        if not isinstance(self.subnodes, list):
            self[self.nodeid] = []
        self.subnodes.append(val)

    def remove( self, val ):
        "self item remove"
        self[ self.nodeid ].remove( val )

    def getsubnodes(self):
        "self item return"
        return self[self.nodeid]

    subnodes = property(getsubnodes)
    "Node.subnodes is a list of subnode instances. "

    def getattrs(self):
        "Return keys filtered by prefix. "
        attrs = {}
        for key in self:
            if key.startswith(self.__prefix__):
                attrs[key[1:]] = self[key]
        return attrs

    attributes = property(getattrs)
    "Node.attributes is a list of attributes with prefix stripped from keys. "

    def __getattr__(self, name):
        # @xxx: won't properties show up in __dict__?
        #print self, '__getattr__', name
#        if name in self.__dict__ or name in ('name', 'subnodes', 'attributes'):
        if len(name) > 4 and name[:2] + name[-2:] == '__'+'__':
            return super(TreeNodeDict, self).__getattribute__(name)
        if self.__prefix__+name in self:
            return self[self.__prefix__+name]

    def __setattr__(self, name, subnodes):
        if len(name) > 4 and name[:2] + name[-2:] == '__'+'__':
#            return super(TreeNodeDict, self).__getattribute__(name)
            super(TreeNodeDict, self).__setattr__(name, subnodes)
        else:
            self[self.__prefix__+name] = subnodes

    def __repr__(self):
        return "<%s%s%s>" % (self.name or lib.cn(self),
                self.attributes or hex(id(self)), self.subnodes or '')

    def copy(self):
        return self.deepcopy()

    def deepcopy(self):
        """
        XXX: Dump to real dict tree which pformat can print.
        """
        d = {}
        def _copy(v):
            if isinstance(v, self.__class__):
                return v.deepcopy()
            else:
                Klass = v.__class__
                return Klass(self[k])
        for k in self:
            v = self[k]
            if v:
                if k == self.nodeid:
                    d[k] = [ _copy(sub) for sub in v ]
                else:
                    d[k] = _copy(v)
            else:
                d[k] = None
        return d

class TreeTraveler(object):
    zope.interface.implements(res_iface.ITraveler)
    def travel(self, root, visitor):
        """
        Start a tree traversal, using the current nodeid as root point
        and retrieving ITree interfaces for each key?
        """
        _x_sanity_iface_node(root)
        assert visitor.context == self
        # XXX
        for x in visitor.traverse(root):
            #print 'travel', x
            pass



gsm = getGlobalSiteManager()
gsm.registerAdapter(TreeNodeDict, [iface.IPyDict], res_iface.ITree)
gsm.registerAdapter(TreeTraveler, [res_iface.ITree], res_iface.ITraveler)

from zope.interface.verify import verifyObject
def _x_sanity_iface_node(obj): # TEST
    assert iface.Node.providedBy(obj), obj
    verifyObject( iface.Node, obj )

class TreeNodeTriple(tuple):

    zope.interface.implements(res_iface.ITree)

    """
    TreeNode build on top of tuple. XXX: Unused.
    Triple is id, attributes and subnodes.
    """


def translate_xml_nesting(tree):

    """
    Translate TreeNode to a dict/list structure that is more like
    the nodes of a DOM tree.
    """

    newtree = {'children':[]}
    for k in tree:
        v = tree[k]
        if k.startswith('@'):
            if v:
                assert isinstance(v, (int,float,basestring)), v
            assert k.startswith('@'), k
            newtree[k[1:]] = v
        else:
            assert not v or isinstance(v, list), v
            newtree['name'] = k
            if v:
                for subnode in v:
                    newtree['children'].append( translate_xml_nesting(subnode) )
    assert 'name' in newtree and newtree['name'], newtree
    if not newtree['children']:
        del newtree['children']
    return newtree


class AbstractHierarchicalVisitor(object):

    """
    IHierarchicalVisitor implementation implements tree traversal using
    IVisitorAcceptor.

    http://c2.com/cgi/wiki?HierarchicalVisitorPattern
    """

    zope.interface.implements(res_iface.IHierarchicalVisitor)

    def traverse(self, root, acceptorname='', acceptor=None):
        """
        Query tree object for IVisitorAcceptor interface,
        invoke ``accept`` and return result.

        Returning does allow ``accept`` to return a depth-first generator
        of ``visit*`` results.
        """
        log.debug('traverser : acceptor', root, acceptor, acceptorname)
        assert iface.Node.providedBy(root), root
        tree = res_iface.ITree(root)
        if not acceptor:
            acceptor = res_iface.IVisitorAcceptor(tree, acceptorname)
        log.debug('traverser -> acceptor.accept', tree, acceptor, acceptorname)
        return acceptor.accept(self)

    def visitEnter(self, node):
        """
        Start visit to IHier, return boolean to signal IVisitorAcceptor to recurse
        """
        raise NotImplementedError

    def visitLeave(self, node):
        """
        Complete visit to IHier, return result.
        """
        raise NotImplementedError

    def visit(self, leaf):
        """
        Do visit to non-IHier, return result.
        """
        raise NotImplementedError

from zope.component import \
        getGlobalSiteManager


gsm = getGlobalSiteManager()

class NodeIDExtractor(AbstractHierarchicalVisitor):

    zope.interface.implements(res_iface.IHierarchicalVisitor)

    def visitEnter(self, o):
        node = iface.Node(o)
        return True

    def visitLeave(self, o):
        node = iface.Node(o)
        if node:
            return node.nodeid

    def visit(self, o):
        node = iface.Node(o)
        if node:
            return node.nodeid

#gsm.registerAdapter(res_iface.IHierarchicalVisitor, , '', NodeIDExtractor)


class AbstractAdapter(object):
    def __init__(self, context):
        self.context = context

class TreeNodeAcceptorAdapter(AbstractAdapter):
    def accept(self, visitor):
        """
        Called by visitor.traverse. Descends tree, queries for IVisitorAcceptor
        and starts nested ``.accept()`` call.

        XXX Anything not providing IVisitorAcceptor in the tree is treated as
        leaf.
        """
        # let visitor decide, then look for subnodes
        if visitor.visitEnter(self.context) and self.context.subnodes:
            for node in self.context.subnodes:
                # recurse ``accept`` to sub-acceptor
                acceptor = res_iface.IVisitorAcceptor(node)
                if acceptor:
                    # relay depth-first generator
                    sub = acceptor.accept(visitor)
                    for generated in sub:
                        yield generated
                else:
                    # ... or do leaf visit
                    yield visitor.visit(node)
        # visit and yield result at the end of the node visit
        yield visitor.visitLeave(self.context)

gsm.registerAdapter(TreeNodeAcceptorAdapter, [res_iface.ITree], res_iface.IVisitorAcceptor, '')
gsm.registerAdapter(TreeNodeAcceptorAdapter, [res_iface.ITree], res_iface.IVisitorAcceptor, 'generator')

class TreeLeafAcceptorAdapter(AbstractAdapter):
    def accept(self, visitor):
        yield visitor.visit( self.context )
gsm.registerAdapter(TreeLeafAcceptorAdapter, [res_iface.ILeaf], res_iface.IVisitorAcceptor, '')
gsm.registerAdapter(TreeLeafAcceptorAdapter, [res_iface.ILeaf], res_iface.IVisitorAcceptor, 'generator')


class DictNodeUpdater(AbstractHierarchicalVisitor, AbstractAdapter):
    zope.interface.implements(res_iface.IHierarchicalVisitor)
    def visitEnter(self, node):
        print 'visitEnter update %s < %s' %( self.context, node), node.nodeid, node.name
        #print self, 'DictNodeUpdater.visitEnter', node
        return True
    def visitLeave(self, node):
        #print self, 'DictNodeUpdater.visitLeave', node
        return node
    def visit(self, node):
        print 'visit update %s < %s' %( self.context, node), node.nodeid, node.name
        #print self, 'DictNodeUpdater.visit', node
        return node


