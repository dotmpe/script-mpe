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

- XXX: the name module is misused abit in a python context in that here it is a class
  providing various instance methods called targets. Rewrite possibly.
"""
import inspect
import sys


import log
import lib
import confparse


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

    # Static

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
        # auto static register
        if name.name not in clss.instances:
            clss.instances[name.name] = self
        else:
            log.warn("%s already in %s.instances",(self, clss))

# FIXME: add parameters
    def __repr__(self):
        return "Target[%r]" % self.name_id

    def __str__(self):
        return "Target[%s]" % self.name
    
    @property
    def name_id(self):
        return self.name.name.replace('-', '_').replace(':', '_')

    @property
    def handler(self):
        mod_class = Target.get_module(self)
        return getattr(mod_class(), target.name_id)

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


class ExecGraph(object):

    """
    This allows to model interdependencies of nodes in the execution tree,
    and provide a session context for results generated by individual targets.
    Ie. result objects are linked to their original target execution context.

    Targets should be represented by nodes, interdependencies are structured by
    directed links between nodes. Links may be references to the following
    predicate names:

    - cmd:prequisite
    - cmd:request
    - cmd:result
  
    Connected as in this schema::

          Tprerequisite  <--- Tcurrent ---> Trequest
                                 |
                                 V
                         Tresult or Rresult  
                               
    T represents an ITarget, R for IResource. Only ITarget can be executed,
    though a target may be a factory (one-to-one instance cardinality) for a 
    certain resource.

    Targets are parametrized by a shared, global context expressed in a
    dictionary, 'kwds'. These parameters do not normally affect their identity.
    Targets gain access to results of other targets through this too, as it is 
    updated in place.

    TODO: arguments list?
    XXX: schema for all this?

    Targets depend on their prequisites, and on their generated requirements.
    Required targets cannot depend on their generator. 
    Result targets may, but need not to depend on their generator.

    If a 'cmd:result' points to a target, it is executed sometime after 
    the generator target. The object of this predicate may also be a
    non-target node, representing an calculated or retrieve object that 
    implements IFormatted, and may implement IResource or IPersisted.

    All links branch out from the current node (the execution target),
    allowing to retrieve the next target.
    Target may appear at multiple places as dependencies.
    Targets are identified by an opaquely generated key, allowing a target
    to parametrize its ID. This should also ensure dependencies are uniquely
    identified and executed only once. The target's implementation should
    select the proper values to do this.

    Through these links an additional structure is build up, the dynamic
    execution tree. ExecGraph is non-zero until all nodes in this tree are
    executed.  Because the nodes of this tree are not unique, a global 
    pointer is kept to the current node of this tree. Execution resolution
    progresses depth-first ofcourse since nested targets are requirements.
    Result targets are executed at the first lowest depth they occur.
    ie. the same level of- but after their generator.
    The structure is asimple nested list with node keys.
    The final structure may be processed for use in audit trails and other 
    types of session- and change logs.
    """

# XXX: work in progress

    def __init__(self, root=[]):
        # lookup map for node instances
        self.nodes = {}
        # P(s,o) lookup map for target and results structure
        self.edges = confparse.Values(dict(
                sub={},
                pred={},
                ob={}
            ))
        # nested tree structure
        if root:
            for i, node in enumerate(root):
                assert not isinstance(node, list), "Is that needed?"
                root[i] = self.deref(node)
        self.exectree = root

    @staticmethod
    def init(node):
        n = Name.fetch(node)
        return Target.fetch(n)

    def instance(self, node):
        if not res.iface.ITarget.providedBy(node):
            node = ExecGraph.init(node)
        return node

    def append(self, S_target, O_target):
        S_target = self.instance(S_target)
        node = self.nodes[S_target.key]
        O_target = self.instance(O_target)
        node.results.append(O_target)

    def require(self, S_target, O_target):
        S_target = self.instance(S_target)
        node = self.nodes[S_target]
        O_target = self.instance(O_target)
        node.requires.append(O_target)

    def __getitem__(self, node):
        return self.get(node)

    def get(self, node):
        return self.nodes[node]

    def set(self, node):
        self.nodes[node]

    def start(self, node):
        assert node in self.nodes
        self.current_node = node

    @property
    def current(self):
        return self.nodes[self.current_node]
        
    def __nonzero__(self):
        return not self.finished()

    def finished(self):
        return not self.current_node

    def nextTarget(self):
        if isinstance(self.current, list):
            pass
        if self.current.depends:
            pass
        if self.current.requires:
            pass
        if self.current.results:
            pass



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

    def main(self):
      
        execution_graph = ExecGraph(self.handlers)
        stack = ContextStack()
        self.run(execution_graph, stack)

    def run(self, execution_graph, context, args=[], kwds={}):

        target = execution_graph.nextTarget()

        context.generator = target(
                        **self.select_kwds(target, kwds))

        for r in context.generator:
            assert not args, "TODO: %s" % args
            if res.ITarget.providedBy(r):
                if r.required:
                    execution_graph.require(target, r)
                    self.run(execution_graph, context, args=args, kwds=kwds)
                else:
                    execution_graph.append(target, r)
            elif isinstance(r, int):
                if r == 0:
                    assert not execution_graph, '???'
                sys.exit(r)
            elif isinstance(r, arguments):
                args.extend(arguments)
            elif isinstance(r, keywords):
                kwds.update(keywords)

        del context.generator

    def select_kwds(self, target, kwds):
        func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
                inspect.getargspec(target.handler)
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



# XXX: trying to rewrite to hierarchical target resolver

    def fetch_target(self, name):
        n = Name.fetch(name)
        return Target.fetch(n)

    def main_old():
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



