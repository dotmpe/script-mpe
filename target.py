"""
Defines the AbstractTargetResolver, which runs targets of registered
handler modules.

See main

- Targets are methods on registered classes.
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

"""
import inspect
import sys


import log
import lib



class targets(tuple):
    def __init__(self, *args):
        self.required = False
        tuple.__init__(self)
    def required(self):
        self.required = True
        return self
    def __str__(self):
        return 'targets'+tuple.__str__(self)
class keywords(dict): 
    def __str__(self):
        return 'keywords'+tuple.__str__(self)
class arguments(tuple): 
    def __str__(self):
        return 'arguments'+tuple.__str__(self)

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
        return "%s:%s" % (self.prefix, self.local_name)
        return "Name(%r, ns=%r)" % (self.name, self.ns)

    def __str__(self):
        return "%s:%s" % (self.prefix, self.local_name)

    instances = {}
    "Static map of name, target instances. "

    @classmethod
    def fetch(clss, name, ns=None):
        if isinstance(name, Name):
            return name
        assert ':' in name, name
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

    def __repr__(self):
        return "Target[%r]" % self.name

    def __str__(self):
        return "Target[%s]" % self.name

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
       
        execution_list = []

        log.info("Starting with: %s", " ".join(self.handlers))
        for h in self.handlers:
            target = self.fetch_target(h)
            execution_list.append(target)

        kwds = {}

        hl = len(execution_list)
        ti = 0
        ei = 0
        while ti < len(execution_list):
            target = execution_list[ti]
            ei += 1
            #log.debug("At iteration %s", ei)
            #log.debug("At index %s", ti + 1)
            assert isinstance(ti, int)

            """
            Skip if the action was already performed,
            perhaps as dependency of an earlier target.
            """
            if target in execution_list[:ti]:
                ti += 1
                assert False
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
                    #    (dep not in execution_list[:ti+1]), \
                    #        "Cyclical: depency %s for %s" % (dep, target)
                    if dep not in execution_list[:ti]:
                        log.note('New depedency {bwhite}%s {default}for {bwhite}%s', dep, target)
                        execution_list.insert(ti, dep)
                    else:
                        log.debug('Already satisfied %s for %s', dep, target)

                if execution_list[ti] != target:
                    #log.debug('Restarting, new depedencies (#%s; @%s)', 
                    #        ei, ti+1)
                    continue

            log.info("{bblue}Executing{bwhite} @%s.{default} %s", 
                    ti, str(target))
            mod_class = Target.get_module(target)
            handler = getattr(mod_class(), target.name_id)
            # execute and iterate through generator
            ret = handler(**self.select_kwds(handler, kwds))
            # TODO: suspend and stack operations for sub targets
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
                    r = targets([r])
                elif isinstance(r, keywords):
                    kwds.update(r)
                if isinstance(r, targets):
                    for epi in r:
                        a = self.fetch_target(epi)
                        if a in execution_list[:ti]:
                            log.note("Already satisfied epilogue? %s", a)
                            continue
                        #    (a.name.name not in target.depends) and \
                        assert (a != target) and \
                            (a not in execution_list[:ti]), \
                                "Cyclical: epilog %s for %s" % (a, target)
                        epilogue.append(a)
           
            #if epilogue:
            #    print 'new epilogue', [t.name for t in epilogue]
            for epi in epilogue:
                execution_list.insert(ti+1, epi)

            ti += 1
            log.info("{bblue}Done{bwhite}: %s{default}", target)
            log.debug("Looping, ready for iteration #%s, index @%s; %s more steps", 
                    ei, ti+1, len(execution_list[ti:]))


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



