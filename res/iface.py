"""
Collection of interfaces.

Another reiteration of a previous unfinished implementation in taxus_out.
"""
from zope.interface import Interface, Attribute, implements, classImplements



class ISimpleCommand(Interface):
    """
    """

class IName(Interface):
    """
    """

class ITarget(IName):
    """
    A static reference to a global target handler implementation
    registered to some code block.
    """
    handler = Attribute("The actual handler. This returns a generator. ")
    depends = Attribute("Static dependencies, a list of ITarget. ")

class ICommand(Interface):
    """
    A reference to an ITarget that keeps pre- and post execution state
    variables.
    """
    prerequisites = Attribute("Static dependencies, a list of ICommand "
            "TODO: or IResource")
    requirements = Attribute("Dynamic targets, a list of ICommand. "
            "TODO: or IResource")
    results = Attribute("Results: targets and resources, a list of ICommand or "
            "IResource. ")

    fetch = Attribute("")

class Node(Interface):
    """
    Someting with an ID.
    Something with a name?
    Something with stat info?
    XXX Node is an abtract concept, not either concrete object or class type?
    Node, not INode to not confuse with res.fs.INode, but still an interface not a normal class.
    """
    nodeid = Attribute("")

class IHier(Node):
    """
    Composite of Node's. No form of semantics expressed (aggregation,
    composition, containment, generalization, etc).

    - could contain nodes or refs
    """
    #supernode = Attribute("Another Node that lists this node as one of its subnodes. ")
    subnodes = Attribute("Object reference to IList of other Node objects. ")
    # subnode methods
    append = Attribute("subnodes IList.append")
    remove = Attribute("subnodes IList.remove")

class ITree(IHier):
    """
    """
    # added attributes data
    attributes = Attribute("Object reference to the attributes as IDict")
    get_attr = Attribute("Wrap IDict.__getitem__. ")
    set_attr = Attribute("Wrap IDict.__setitem__, and IDict.__delitem__ for None values. ")

class ILeaf(Node):
    pass


class IVisitorAcceptor(Interface):
    """
    Generic interface for leafs/nodes in structurs to accept
    visistors, and to defer them to substructeres if applicable.
    """
    accept = Attribute("XXX boolean indicating wether visitor was succesfully applied?")


class IHierarchicalVisitor(Interface):
    """
    Interface for ITree visitors. 

    http://c2.com/cgi/wiki?HierarchicalVisitorPattern
    """
    visitEnter = Attribute("visitEnter(self, node): return true when IVisitorAcceptor should try to recurse")
    visitLeave = Attribute("visitLeave(self, node)")
    visit = Attribute("visit(self, leaf)")
   
    traverse = Attribute("Not part of the API, b/c parametrized?")

class ITraveler(Interface):
    travel = Attribute("travel( root, visitor )")

class ILocalNodeService(Interface):
    """
    # Let ILocalNodeService produce something Node-like for local
    # system paths/names/ids.
    """


from taxus.iface import IPrimitive

class IPyDict(IPrimitive):
    pass

classImplements(dict, IPyDict)

# See taxus.iface for adapters
#registry = AdapterRegistry()
# Adapt [1] to 2 using 4, give tag/name 3
#registry.register([IID], IFormatted, '', IDFormatter)


def test():
    from zope.interface.verify import verifyObject
    verifyObject(ITarget, Target())


