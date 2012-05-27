"""
Defines the AbstractTargetResolver, which runs targets of registered
handler modules.

See main
"""
import inspect
import sys


import log
import lib



class Name(object):

    def __init__(self, name, ns=None):
        assert ':' in name, (name, ns)
        if not ns:
            p = name.index(':')
            ns = lib.namespaces[name[:p]]
        self.name = name
        self.ns = ns

    @property
    def local_name(self):
        p = self.name.index(':')
        return self.name[p+1:]

    @property
    def prefix(self):
        p = self.name.index(':')
        return self.name[:p]

    def __repr__(self):
        return "Name(%r, ns=%r)" % (self.name, self.ns)

    def __str__(self):
        return self.local_name()

    instances = {}
    "Static map of name, target instances. "

    @classmethod
    def fetch(clss, name, ns=None):
        if isinstance(name, Name):
            return name
        assert ':' in name
        if name not in clss.instances:
            n = Name(name, ns)
            clss.instances[name] = n
        else:
            n = clss.instances[name]
        return n


class Target(object):

    def __init__(self, name, depends=[], values={}):
        assert isinstance(name, Name), name
        self.name = name
        self.depends = depends
        self.values = values

        clss = self.__class__
        if name.name not in clss.instances:
            clss.instances[name.name] = self
        else:
            log.warn("%s already in %s.instances",(self, clss))
   
    instances = {}
    "Static map of name, target instances. "

    def __str__(self):
        return "Target:%r" % self.name

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

    modules = {}
    "Mapping of NS prefix, Objects providing target handlers"
    module_list = []

    @classmethod
    def register(clss, handler_module):
        assert handler_module not in clss.module_list
        clss.module_list.append(handler_module)

        for hid in handler_module.depends:

            # Register each target if not already instantiated
            hid = clss.parse_name(hid, handler_module.namespace)
            hname = Name.fetch(hid)
            depids = [
                clss.parse_name(depid, handler_module.namespace)
                for depid in handler_module.depends[hname.name]
            ]
            target_handler = clss.register_target(hname, depids)

            # This would allow mapping a target instance back to its class
            # XXX: this has not been in use 
            hns = hname.prefix
            if hns not in clss.modules:
                clss.modules[hns] = []
            clss.modules[hns].append(handler_module)

    @classmethod
    def get_module(clss, target):
        nsprefix = target.name.prefix
        tname = target.name.name
        for mod in clss.modules[nsprefix]:
            if tname in mod.depends:
                return mod
        assert False, "No module for %s" % tname

    @classmethod
    def fetch(clss, name):
        assert name.name in clss.instances, "No such target: %s" % name.name
        return clss.instances[name.name]
    
    @property
    def name_id(self):
        return self.name.name.replace('-', '_').replace(':', '_')


class AbstractTargetResolver(object):

    namespace = None, None

    handlers = [
#            'cmd:targets'
        ]
    depends = {
#            'cmd:targets': [ 'cmd:options' ]
        }

    depends = {
        }

    def fetch_target(self, name):
        n = Name.fetch(name)
        return Target.fetch(n)

    def main(self):
       
        targets = []

        for h in self.handlers:
            target = self.fetch_target(h)
            targets.append(target)

        kwds = {}

        ti = 0
        while ti < len(targets):
            target = targets[ti]
            log.info(str(target))

            """
            Skip if the action was already performed,
            perhaps as dependency of an earlier target.
            """
            if target in targets[:ti]:
                ti += 1
                print 'skipped', ti, target
                continue

            """
            Prepend any dependency before the current target.
            """
            if target.depends:
                for dep in target.depends:
                    dep = self.fetch_target(dep)
                    #print 'dep', dep, target
                    #assert (dep != target) and \
                    #    (dep not in targets[:ti+1]), \
                    #        "Cyclical: depency %s for %s" % (dep, target)
                    if dep not in targets[:ti]:
                        targets.insert(ti, dep)
                if targets[ti] != target:
                    #print 'new depends', target.depends
                    continue

            mod_class = Target.get_module(target)
            handler = getattr(mod_class(), target.name_id)
            ret = handler(**self.select_kwds(handler, kwds))
            if isinstance(ret, list):
                ret = tuple(ret)
            if not ( inspect.isgenerator(ret) or isinstance(ret, tuple) ):
                ret = (ret,)
           
            epilogue = []
            for r in ret:
                # use integer to indicate target status, request interupts
                if isinstance(r, int):
                    sys.exit(r)
                # strings refer to the id of the action to run next
                elif isinstance(r, str):
                    r = [r]
                elif isinstance(r, dict):
                    kwds.update(r)
                if isinstance(r, list):
                    for epi in r:
                        a = self.fetch_target(epi)
                        #    (a.name.name not in target.depends) and \
                        assert (a != target) and \
                            (a not in targets[:ti]), \
                                "Cyclical: epilog %s for %s" % (a, target)
                        epilogue.append(a)
           
            #if epilogue:
            #    print 'new epilogue', [t.name for t in epilogue]
            for epi in epilogue:
                targets.insert(ti+1, epi)

            ti += 1

    def select_kwds(self, handler, kwds):
        func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
                inspect.getargspec(handler)
        assert func_arg_vars.pop(0) == 'self'
        ret_kwds = {}

        if func_defaults:
            func_defaults = list(func_defaults) 

        while func_defaults:
            arg_name = func_arg_vars.pop()
            value = func_defaults.pop()
            if arg_name in kwds:
                value = kwds[arg_name]
            ret_kwds[arg_name] = value
        
        if "options" in ret_kwds:
            ret_kwds['options'] = opts

        return ret_kwds



