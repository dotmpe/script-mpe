import zope.interface

import confparse
import res
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
    def register(klass, prefix, uriref):#, preferred=True, override_preferred=False):
        # fetch or init Ns
        if uriref in klass.instances:
            ns = klass.instances[uriref]
            if prefix not in ns.prefixes:
                ns.prefixes.append(prefix)
        else:
            ns = klass(prefix, uriref, prefixes=[prefix])
            klass.instances[uriref] = ns
        # validate or assert prefix
        if prefix in klass.prefixes:
            assert klass.prefixes[prefix] == uriref
        else:
            klass.prefixes[prefix] = uriref

        return ns

    @classmethod
    def fetch(klass, prefix):
        return klass.instances[klass.prefixes[prefix]]


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
    def fetch(klass, name, ns=None):
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
        if n.qname not in klass.instances:
            klass.instances[name] = n
        else:
            n1 = klass.instances[name]
            assert n == n1
        return n

    @classmethod
    def register(klass, **props):
        assert 'prefix' in props
        ns = confparse.Values(props)
        klass.namespaces[ns.prefix] = ns
        return ns
