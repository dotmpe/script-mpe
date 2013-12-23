"""
Classes using primitive values and dict and lists.

TreeNode
    key
        Unique name or ID
    value 
        List of TreeNode instances; subnodes

    Besides key and value, TreeNode supports others attributes.
    As long as these don't collide with TreeNodeDict (and Python dict).

"""

class TreeNodeDict(dict):

    """
    TreeNode build on top of dict, and with attributes.
    Dict contains an name to subnodes mapping, and attribute values.

    Each attribute is stored with prefixed key, to make it distinct from the 
    name.

    XXX: Normally TreeNodeDict contains one TreeNode, but the dict would allow
    for multiple branchings?
    """

    prefix = '@'
    "static config for attribute prefix"
    
    def __init__(self, name):
        dict.__init__(self)
        self[name] = None

    def getname(self):
        for key in self:
            if not key.startswith(self.prefix):
                return key

    def setname(self, name):
        oldname = self.getname()
        val = self[oldname]
        del self[oldname]
        self[name] = val

    name = property(getname, setname)

    def append(self, val):
        if not isinstance(self.value, list):
            self[self.name] = []
        self.value.append(val)

    def getvalue(self):
        return self[self.name]

    value = property(getvalue)

    def getattrs(self):
        attrs = {}
        for key in self:
            if key.startswith(self.prefix):
                attrs[key[1:]] = self[key]
        return attrs

    attributes = property(getattrs)

    def __getattr__(self, name):
        if name in self.__dict__ or name in ('name', 'value', 'attributes'):
            return super(TreeNodeDict, self).__getattr__(name)
        elif '@'+name in self:
            return self[self.prefix+name]

    def __setattr__(self, name, value):
        if name in self.__dict__ or name in ('name', 'value', 'attributes'):
            super(TreeNodeDict, self).__setattr__(name, value)
        else:
            self[self.prefix+name] = value

    def __repr__(self):
        return "<%s%s%s>" % (self.name, self.attributes, self.value or '')

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
                if k == self.name:
                    d[k] = [ _copy(sub) for sub in v ]
                else:
                    d[k] = _copy(v)
            else:
                d[k] = None
        return d

class TreeNodeTriple(tuple):

    """
    TreeNode build on top of tuple. XXX: Unused, not implemented. 
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

