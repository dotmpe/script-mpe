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

from script_mpe.res import iface



class TreeNodeDict(dict):

    """
    TreeNode build on top of dict, and with attributes.
    Dict contains an name to subnodes mapping, and attribute values.

    Each attribute is stored with prefixed key, to make it distinct from the 
    name.

    XXX: Normally TreeNodeDict contains one TreeNode, but the dict would allow
    for multiple branchings?
    """

    zope.interface.implements(iface.ITreeNode)

    prefix = '@'
    "static config for attribute prefix"
    
    def __init__(self, nodeid):
        dict.__init__(self)
        self[nodeid] = None

    def getid(self):
        for key in self:
            if not key.startswith(self.prefix):
                return key

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
            if key.startswith(self.prefix):
                attrs[key[1:]] = self[key]
        return attrs

    attributes = property(getattrs)
    "Node.attributes is a list of attributes with prefix stripped from keys. "

    def __getattr__(self, name):
        # @xxx: won't properties show up in __dict__?
        #print self, '__getattr__', name
#        if name in self.__dict__ or name in ('name', 'subnodes', 'attributes'):
#            return super(TreeNodeDict, self).__getattr__(name)
        if self.prefix+name in self:
            return self[self.prefix+name]

    def __setattr__(self, name, subnodes):
#        if name in self.__dict__ or name in ('name', 'subnodes', 'attributes'):
#            super(TreeNodeDict, self).__setattr__(name, subnodes)
        self[self.prefix+name] = subnodes

    def __repr__(self):
        return "<%s%s%s>" % (self.name, self.attributes, self.subnodes or '')

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


class TreeNodeTriple(tuple):

    zope.interface.implements(iface.ITreeNode)

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

