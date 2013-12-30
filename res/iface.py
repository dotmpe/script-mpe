import zope.interface
from zope.interface import Interface, Attribute, implements
from zope.interface.interface import adapter_hooks
from zope.interface.adapter import AdapterRegistry
from zope.component.factory import IFactory
from zope.component import \
        getGlobalSiteManager


gsm = getGlobalSiteManager()

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

# treemap, res/primitive additions
# XXX: should this perhaps inherit IPrimitive
class IPyDict(zope.interface.Interface): pass
class IPyList(zope.interface.Interface): pass
class IPyTuple(zope.interface.Interface): pass

zope.interface.classImplements(list, IPyList)
zope.interface.classImplements(dict, IPyDict)
zope.interface.classImplements(tuple, IPyTuple)


from res.fs import Dir
class IDir(zope.interface.Interface):
    filters = Attribute("XXX Formalize res.fs.File,Dir?")
    tree = Attribute("Return ITreeNode object for path, tree obeys filters")
    walk = Attribute("Return TreeNodeDict based on filters")
gsm.registerUtility(Dir, IDir)
gsm.registerUtility(Dir.tree, IFactory, 'inodetree') 
gsm.registerUtility(Dir.walk, IFactory, 'dicttree') 

class Node(zope.interface.Interface):
    """
    XXX emphasize Node is an abtract concept, not either concrete object or class type?
    Node, not INode to not confuse with res.fs.INode, but still an interface not a normal class.
    """
    name = Attribute("")

class IHier(Node):
    """
    Composite of Node's. No form of semantics expressed (aggregation,
    composition, containment, generalization, etc).
    """
    supernode = Attribute("Another Node that lists this node as one of its subnodes. ")
    subnodes = Attribute("Object reference to IList of other Node objects. ")

class ITreeNode(Node):
    """
    Adding attributes to IHiertree structure
    """
    # subnode methods
    append = Attribute("subnodes IList.append")
    remove = Attribute("subnodes IList.remove")
    # added attributes data
    attributes = Attribute("Object reference to the attributes as IDict")
    get_attr = Attribute("Wrap IDict.__getitem__. ")
    set_attr = Attribute("Wrap IDict.__setitem__, and IDict.__delitem__ for None values. ")


registry = AdapterRegistry()
# Adapt [1] to 2 using 4, give tag/name 3
#registry.register([IID], IFormatted, '', IDFormatter)


def test():
    from zope.interface.verify import verifyObject
    verifyObject(ITarget, Target())
