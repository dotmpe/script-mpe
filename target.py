"""target

    Namespace
     - prefix (global preference)
     - prefixes (alt.; non-unique or distinct)
     - uriref (canonical ID)

    Name
     - name
     - &ns:Namespace
     - @qname
     
    Target
     - &name:Name
     - &handler (callable)
     - depends

    ExecGraph
     - from/to/three:<Target,Target,Target>
     - execlist (minimally cmd:options, from there on: anything from cmdline)

    ContextStack


See main

- Targets are recipes to perform particualr tasks. 
- Targets selectively accept keywords from a known pool of keys.
- Targets may depend on other targets:
  
  - prerequisites are targets executed before, and
  - TODO: subtargets are targets that are executed during another target
    and need to finish before the target can complete.
  - Epilogue targets run after a target has completed.
  
- Target execution order and the *prerequisite dependency chain* is hardcoded,
  sub- and epilogue targets are dynamic.
- Targets are generators once executed, yields may be auxiliary structures such as 
  a lists of sub- or epilogue targets.
- The keywords aux. structure defines additional parameters to sub(sequent) targets.
- The targets aux. structure defines additional targets to run, as a subtarget 
  if targets.required is True, or after else as first thing the epilogue.

- FIXME: The arguments aux. structure is unused.
- The arguments aux. structure may be used to communicate generic or  
  iterable paramers to (sub)targets.

- XXX: the name module is misused abit in a python context in that here it is a class
  providing various instance methods called targets. Rewrite possibly.


"""
import sys

import zope.interface

import log
import lib
import res
import confparse



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


class Target(object):

    zope.interface.implements(res.iface.ITarget)

    def __init__(self, name, depends=[], handler=None, values={}):
        assert isinstance(name, Name), name
        self.name = name
        self.depends = list(depends)
        self.handler = handler
        self.values = values
        clss = self.__class__
        # auto static register
        if name.qname not in clss.instances:
            clss.instances[name.qname] = self
        else:
            log.warn("%s already in %s.instances",(self, clss))

    # FIXME: add parameters
    def __repr__(self):
        return "Target[%r]" % self.name_id

    def __str__(self):
        return "Target[%s]" % self.name
    
    @property
    def name_id(self):
        return self.name.qname.replace('-', '_').replace(':', '_')

    # Static

    instances = {}
    "Mapping of name, target instances. "

    @staticmethod
    def parse_name(name, default_ns=None):
        if ':' in name:
            nsid = name.split(':')[0]
            ns = lib.namespaces[nsid]
        else:
            ns = default_ns.namespace

        if ':' not in name:
            assert ns, ('parse_name', name, default_ns)
            name = ns[0] +':'+ name
        
        return name

    @classmethod
    def register_target(clss, handler_name, depends):
        hname = handler_name
        if not isinstance(handler_name, Name):
            hname = Name.fetch(hid)
        if hname.name not in clss.instances:
            deps = []
            for depid in depends:
                depname = Name.fetch(depid)
                deps.append(depname)
            h = clss(hname, deps)
        return clss.instances[hname.name]

    @classmethod
    def fetch(clss, name):
        assert isinstance(name, Name), name
        assert name.name in clss.handlers
        return clss.handlers[name.name]
# XXX
        assert name.name in clss.instances, "No such target: %s" % name.name
        return clss.instances[name.name]

#    modules = {}
#    "Mapping of NS prefix, Objects providing target handlers"
#    module_list = []
#
#    @classmethod
#    def register(clss, handler_module):
#        assert handler_module not in clss.module_list
#        clss.module_list.append(handler_module)
#
#        for hid in handler_module.depends:
#
#            # Register each target if not already instantiated
#            hid = clss.parse_name(hid, handler_module.namespace)
#            hname = Name.fetch(hid)
#            depids = [
#                clss.parse_name(depid, handler_module.namespace)
#                for depid in handler_module.depends[hname.name]
#            ]
#            target_handler = clss.register_target(hname, depids)
#
#            # This would allow mapping a target instance back to its class
#            # XXX: this has not been in use 
#            hns = hname.prefix
#            if hns not in clss.modules:
#                clss.modules[hns] = []
#            clss.modules[hns].append(handler_module)
#
#    @classmethod
#    def get_module(clss, target):
#        nsprefix = target.name.prefix
#        tname = target.name.name
#        for mod in clss.modules[nsprefix]:
#            if tname in mod.depends:
#                return mod
#        assert False, "No module for %s" % tname


    handlers = {}

    @classmethod
    def register(clss, ns, name, *depends):
        """
        """
        assert ns.prefix in Namespace.prefixes \
                and Namespace.prefixes[ns.prefix] == ns.uriref
        handler_id = ns.prefix +':'+ name
        handler_name = Name.fetch(handler_id, ns=ns)
        def decorate(handler):
            clss.handlers[handler_id] = clss(
                    handler_name,
                    depends=depends,
                    handler=handler,
                )
            return handler
        return decorate

