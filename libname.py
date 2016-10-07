import zope.interface

from . import confparse
from . import res
#import log



class Namespace(object):

    def __init__(self, prefix, uriref, prefixes=[]):
        self.uriref = uriref
        self.prefix = prefix
        if prefix not in prefixes:
            prefixes.append(prefix)
        self.prefixes = prefixes

    # Static

    instances = {}
    "Static map with URI, target instances. "

    prefixes = {}
    "Static map for preferred prefix name. "

    @classmethod
    def register(clss, prefix, uriref):#, preferred=True, override_preferred=False):
        # fetch or init Ns
        if uriref in clss.instances:
            ns = clss.instances[uriref]
            if prefix not in ns.prefixes:
                ns.prefixes.append(prefix)
        else:
            ns = clss(prefix, uriref, prefixes=[prefix])
            clss.instances[uriref] = ns
        # validate or assert prefix
        if prefix in clss.prefixes:
            assert clss.prefixes[prefix] == uriref
        else:
            clss.prefixes[prefix] = uriref

        return ns

    @classmethod
    def fetch(clss, prefix):
        return clss.instances[clss.prefixes[prefix]]


class Name(object):

    zope.interface.implements(res.iface.IName)

    """
    Names are simple strings. They are made globally unique
    by prefixes, such as URI's or QName prefixes. A static part
    keeps a global mapping by QNames.
    """

    def __init__(self, name, ns):
        assert isinstance(ns, Namespace), ns
        self.name = name
        self.ns = ns

    @property
    def qname(self):
        return self.prefix +':'+ self.name

    @property
    def prefix(self):
        return self.ns.prefix

    def __repr__(self):
        return "%s:%s" % (self.prefix, self.name)

    def __str__(self):
        return "%s:%s" % (self.prefix, self.name)

    def __eq__(self, other):
        if hasattr(other, 'name') and hasattr(other, 'ns'):
            if other.name == self.name:
                if other.ns.uriref == self.ns.uriref:
                    return True
        return False

    # Static

    instances = {}
    "Static map of name, target instances. "

    @classmethod
    def fetch(clss, name, ns=None):
        if isinstance(name, Name):
            return name
        assert isinstance(name, str), name
        if ':' in name:
            p = name.index(':')
            if not ns:
                ns = Namespace.fetch(name[:p])
            name = name[p+1:]
        else:
            assert ns
        n = Name(name, ns)
        if n.qname not in clss.instances:
            clss.instances[name] = n
        else:
            n1 = clss.instances[name]
            assert n == n1
        return n

    @classmethod
    def register(clss, **props):
        assert 'prefix' in props
        ns = confparse.Values(props)
        clss.namespaces[ns.prefix] = ns
        return ns




