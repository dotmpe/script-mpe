"""

    Target:ITarget
     - &name:Name
     - &handler (callable)
     - depends

    Handler
     - &func (callable that returns generator)
     - prerequisites (static)
     - requires (dynamic)
     
    Command:ICommand
     - @key (name.qname)
     - &name:Name
     - &handler:Handler
     - graph:Graph
    
    ExecGraph
     - from/to/three:<Target,Target,Target>
     - execlist (minimally cmd:options, from there on: anything from cmdline)

    ContextStack
    OptionParser

"""
import inspect
import optparse
from UserDict import UserDict
import sys

import zope

import lib
import log
from libname import Name, Namespace
import res
from res.iface import IName



def optparse_override_handler(option, optstr, value, parser, new_value):
    """
    Override value of `option.dest`.
    If no new_value given, the option string is converted and used.
    """
    assert not value
    if new_value:
        value = new_value
    else:
        value = optstr.strip('-').replace('-','_')
    values = parser.values
    dest = option.dest
    setattr(values, dest, value)


class OptionParser(optparse.OptionParser):
    
    def __init__(self, usage, version=None):
        optparse.OptionParser.__init__(self, usage, version=version)
        self._targets = None

    def print_help(self, file=None):
        if file is None:
            file = sys.stdout
        encoding = self._get_encoding(file)
        file.write(self.format_help().encode(encoding, "replace"))
        log.info("%s options", len(self.option_list))
        print >> file
        self.print_targets(fl=file)

    @property
    def targets(self):
        """
        Instance property for convenience.
        """
        if not self._targets:
            self._targets = Target.instances.keys()
            self._targets.sort()
        return self._targets
    
    def print_targets(self, fl=None):
        targets = self.targets
        print >>fl, "Targets: "
        for target in targets:
            print >>fl, '  -', target
        print >>fl, len(targets), 'targets'


# Option Callbacks for optparse.OptionParser.

def optparse_increment_message(option, optstr, value, parser):
    "Lower output-message threshold. "
    parser.values.quiet = False
    parser.values.message_level += 1

def optparse_override_quiet(option, optstr, value, parser):
    "Turn off non-essential output. "
    parser.values.quiet = True
    parser.values.interactive = False
    parser.values.message_level = 4 # skip beyond warn: note, info etc

def optparse_print_help(options, optstr, value, parser):
    parser.print_help()



class Handler(object):

    def __init__(self, func=None, prerequisites=[], requires=[], results=[]):
        self.func = func
        self.prerequisites = prerequisites
#        self.requires = requires
#        self.results = results


class Targets(object):#tuple):
    def __init__(self, *args):
        super(Targets, self).__init__()
        self.required = False
        self.items = args
    def required(self):
        self.required = True
        return self
    def __str__(self):
        assert isinstance(self.items, tuple)
        return 'targets%r'%self.items
    def __iter__(self):
        for i in self.items:
            yield i
#    def __add__(self, other):
#        if isinstance(other, (list, tuple, Targets)):
#            return self.items + other

class Keywords(dict): 
    def __init__(self, **kwds):
        dict.__init__(self)
        self.update(kwds)
    def __str__(self):
        return 'keywords %r' % self
    def deep_update(self, other):
        for o in other:
            if o in self:
                if hasattr(self[o], 'deep_update'):
                    self[o].deep_update(other[o])
                elif hasattr(self[o], 'update'):
                    self[o].update(other[o])
                else:
                    self[o] = other[o]
            else:
                self[o] = other[o]

class Arguments(tuple): 
    def __str__(self):
        return 'arguments'+tuple.__str__(self)

class Options(UserDict):
    def __init__(self, **kwds):
        UserDict.__init__(self)
        self.update(kwds)
    def __str__(self):
        return 'options %r' % self

    # static

    attributes = []
    "A list with the definition of each option. "
    opts = []
    ". "
    options = {}
    "A mapping of long and short opts and to their definition index. "
    variables = {}
    "A mapping of (meta)variable names to their option definition index. "

    @classmethod
    def register(clss, ns, *options):

        """
        Registers a standard list of options, compabible with optparse.
        """

        for opts, attrdict in options:

            clss.opts.append(opts)
   
            idx = len(clss.attributes)
            clss.attributes.append(attrdict)

            for opt in opts:
                assert opt not in clss.options
                clss.options[opt] = idx

            for key in 'metavar', 'dest':
                if key in attrdict:
                    varname = attrdict[key]
                    if varname not in clss.variables:
                        clss.variables[varname] = []
                    if idx not in clss.variables[varname]:
                        clss.variables[varname].append(idx)

    @classmethod
    def get_options(clss):
        option_spec = []
        for idx, opts in enumerate(clss.opts):
            attr = clss.attributes[idx]
            option_spec.append((opts, attr))
        return tuple(option_spec)


class ExecGraph(object):

    """
    This allows to model interdependencies of nodes in the execution tree,
    and provide a session context for results generated by individual targets.
    Ie. result objects are linked to their original target execution context.

    Targets should be represented by nodes, interdependencies are structured by
    directed links between nodes. Links may be references to the following
    predicate names:

    - cmd:prerequisite
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

    Targets depend on their prerequisites, and on their generated requirements.
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

#    P_hasPrerequisite = Name.fetch('cmd:hasPrerequisite')
#    P_isPrerequisiteOf = Name.fetch('cmd:isPrerequisiteOf')
#
#    P_requires = Name.fetch('cmd:requires')
#    P_isRequiredFor = Name.fetch('cmd:isRequiredFor')
#
#    P_hasResult = Name.fetch('cmd:hasResult')
#    P_isResultOf = Name.fetch('cmd:isResultOf')

    def __init__(self, root=[], default_namespace=None):
        # P(s,o) lookup map for target and results structure
        self.edges = type('Edges', (object,), dict(
                s_p={},
                s_o={},
                o_p={}
            ))
        self.commands = {}
        self.execlist = []
        self.pointer = 0
        self.default_namespace = default_namespace
        if root:
            for node_id in root:
                self.put(node_id)
    
    def __contains__(self, other):
        other = self.instance(other)
        for i in self.execlist:
            assert res.iface.ITarget.providedBy(i), i
            if other.key == i.key:
                return True
            if other.key in i.depends:
                pass
        assert False

    @staticmethod
    def load(name, default_namespace=None):
        assert isinstance(name, str)
        if not ':' in name:
            assert default_namespace
            name = default_namespace + ':' + name
        target = Target.handlers[name]
        cmdtarget = Command(
                name=target.name,
                handler=Handler(
                    func=target.handler,
                    prerequisites=target.depends))
        assert res.iface.ICommand.providedBy(cmdtarget), cmdtarget
        assert cmdtarget.key, cmdtarget
        assert cmdtarget.key == name, name
        return cmdtarget

    def fetch(self, node, force=False):
        """
        When node is a string, or an object that implements ITarget,
        the matching ICommand is instantiated if needed and returned.
        If node implements ICommand, it is returned after being set 
        if null or overrided if forced. KeyError is raised for 
        duplicates.
        """
        if not res.iface.ICommand.providedBy(node):
            if res.iface.IName.providedBy(node):
                node = node.qname
            # Initialize the requested key if available
            if node not in self.commands:
                cmdtarget = ExecGraph.load(node, self.default_namespace)
                self.commands[cmdtarget.key] = cmdtarget
        else:
            # Use given node as command instance
            if not force and node.key in self.commands:
                raise KeyError, "Key exists: %s" % node.key
            self.commands[node.key] = node
        return self.commands[node]

    def name(self, node):
        if res.iface.ICommand.providedBy(node):
            node = node.key
        if res.iface.IName.providedBy(node):
            node = node.qname
        assert isinstance(node, str), node
        return node

    def index(self, node):
        name = self.name(node)
        assert name in self.execlist
        return self.execlist.index(name)

    def instance(self, node):
        if not res.iface.ICommand.providedBy(node):
            node = self.fetch(node)
            if not node.graph or node.graph != self:
                node.graph = self
                assert node.key in self.execlist, (node.key, self.execlist)
                # resolve static dependencies
                while node.handler.prerequisites:
                    dep = node.handler.prerequisites.pop(0)
                    self.put(dep, self.index(node))
                    self.prerequisite(self.instance(node), dep)
                    log.debug('added prerequisite: %s %s', node, dep)
        assert node.graph == self
        return node

    def prerequisite(self, S_target, O_target):
        """
        assert S has Prerequisite O
        """
        S_target = self.instance(S_target)
        O_target = self.instance(O_target)
        #print self.execlist
        #print 'prerequisite', S_target, O_target
        S_idx = self.execlist.index(S_target.key)
        assert S_idx >= 0, S_idx
        O_idx = self.execlist.index(O_target.key)
        assert O_idx >= 0, O_idx
        # make the edges 
        #XXX:self._assert(S_target, self.P_hasPrerequisite, O_target)
        #(for antonym P_isPrerequisiteOf we can traverse the reverse mapping)

    def isPrerequisite(self, target, prerequisite):
        return False
# FIXME: isPrerequisite
        target = self.instance(target)
        prerequisite = self.instance(prerequisite)
        S = target.name
        P = self.P_hasPrerequisite
        O = prerequisite.name
        while S in self.edges.s_p:
            if O in self.edges.s_p[S][P]:
                return true

#    def prerequisites(self, target):
#        return self.objects(target, self.P_hasPrerequisite)

    def require(self, S_target, O_target):
        """
        assert S requires O
        assert O is required for S
        """
        S_target = self.instance(S_target)
        O_name = self.name(O_target) 
        assert S_target.key in self.execlist
        idx = self.index(S_target.key)
        if O_name not in self.execlist:
            #print 'TODO put', O_name, O_target
            self.put(O_name, idx)
            O_target = self.instance(O_target)
            self.pointer -= 1
        # make the edges 
        #XXX:self._assert(S_target, self.P_requires, O_target)
        #(for antonym we can traverse the reverse mapping)

#    def requires(self, target):
#        return self.objects(target, self.P_requires)

    def result(self, S_target, O_target):
        """
        assert S is Result of O
        """
        # make the edges 
        #XXX:self._assert(S_target, self.P_isResultOf, O_target)
        #(for antonym we can traverse the reverse mapping)

#    def results(self, target):
#        return self.objects(target, self.P_hasResult)

    def objects(self, S, P):
        S = self.instance(S).name
        if S in self.edges.s_p:
            if P in self.edges.s_p[S]:
                return self.edges.s_p[S][P]

    def _assert(self, S_command, P_name, O_command):
        S = self.instance(S_command).name
        P = P_name
        O = self.instance(O_command).name
        if S not in self.edges.s_p:
            self.edges.s_p[S] = {}
        if P not in self.edges.s_p[S]:
            self.edges.s_p[S][P] = []
        if O not in self.edges.s_p[S][P]:
            self.edges.s_p[S][P].append(O)

        if S not in self.edges.s_o:
            self.edges.s_o[S] = {}
        if O not in self.edges.s_o[S]:
            self.edges.s_o[S][O] = []
        if P not in self.edges.s_o[S][O]:
            self.edges.s_o[S][O].append(P)

        if O not in self.edges.o_p:
            self.edges.o_p[O] = {}
        if P not in self.edges.o_p[O]:
            self.edges.o_p[O][P] = []
        if S not in self.edges.o_p[O][P]:
            self.edges.o_p[O][P].append(S)

    def put(self, target, idx=-1):
        assert isinstance(target, str)
        if idx == -1:
            idx = len(self.execlist)
        assert idx >= 0, idx
        assert idx <= len(self.execlist), idx
        assert target in Target.handlers, target
        if target in self.execlist:
            if self.index(target) > idx:
                self.execlist.remove(target)
        if target not in self.execlist:
            self.execlist.insert(idx, target)
        target = self.instance(target)

    def __getitem__(self, node):
        return self.get(node)

    def get(self, node):
        return Target.handlers[node]

    def set(self, node):
        Target.handlers[node]

    @property
    def current(self):
        if self.pointer >= 0 and self.pointer < len(self.execlist):
            return self.execlist[self.pointer]
        
    def __nonzero__(self):
        return not self.finished()

    def finished(self):
        return not self.current

    def nextTarget(self):
        name = self.current
        if not name:
            return
        assert isinstance(name, str), name
        target = self.commands[name]
        assert res.iface.ICommand.providedBy(target), (
                repr(target),list(zope.interface.providedBy(target).interfaces()))
        assert not target.handler.prerequisites
        log.debug('nextTarget index=%s target.name=%s execlist=%r'
                %(
                    self.pointer,
                    target.name,
                    self.execlist
                ))
        self.pointer += 1
        return target


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
            log.warn("%s already in %s.instances", self, clss)

    # FIXME: add parameters
    def __repr__(self):
        return "Target[%r]" % self.name_id

    def __str__(self):
        return "Target[%s]" % self.name
    
    @property
    def name_id(self):
        return self.name.qname.replace('-', '_').replace(':', '_')

    # Static

    handlers = {}

    @classmethod
    def register(clss, ns, name, *depends):
        """
        """
        assert ns.prefix in Namespace.prefixes \
                and Namespace.prefixes[ns.prefix] == ns.uriref
        handler_id = ns.prefix +':'+ name
        handler_name = Name.fetch(handler_id, ns=ns)
        assert handler_id not in clss.handlers, "Duplicate handler %s" % handler_id
        def decorate(handler):
            clss.handlers[handler_id] = clss(
                    handler_name,
                    depends=depends,
                    handler=handler,
                )
            return handler
        return decorate

# XXX:
    instances = {}
    "Mapping of name, target instances. "

    @classmethod
    def fetch(clss, name):
        assert isinstance(name, Name), name
        assert name.name in clss.handlers
        return clss.handlers[name.name]


class Command(object):

    zope.interface.implements(res.iface.ICommand)

    def __init__(self, name=None, handler=None, graph=None):
        self.name = name
        self.handler = handler
        self.graph = graph
    
    @property
    def key(self):
        return self.name.qname

    @property
    def prerequisites(self):
        return self.graph.prerequisites(self)

    @property
    def requires(self):
        return self.graph.requires(self)

    @property
    def results(self):
        return self.graph.results(self)

    def __str__(self):
        return "<Command %r>" % self.name


class ContextStack(object):
    """A stack of states. Setting an attribute overwrites the last
    value, but deleting the value reactivates the old one.
    Default values can be set on construction.
    
    This is used for important states during output of rst,
    e.g. indent level, last bullet type.
    """
    
    def __init__(self, defaults=None):
        '''Initialise _defaults and _stack, but avoid calling __setattr__'''
        if defaults is None:
            object.__setattr__(self, '_defaults', {})
        else:
            object.__setattr__(self, '_defaults', dict(defaults))
        object.__setattr__(self, '_stack', {})

    def __getattr__(self, name):
        '''Return last value of name in stack, or default.'''
        if name in self._stack:
            return self._stack[name][-1]
        if name in self._defaults:
            return self._defaults[name]
        raise AttributeError

    def append(self, name, value):
        l = list(getattr(self, name))
        l.append(value)
        setattr(self, name, l)

    def __setattr__(self, name, value):
        '''Pushes a new value for name onto the stack.'''
        if name in self._stack:
            self._stack[name].append(value)
        else:
            self._stack[name] = [value]

    def __delattr__(self, name):
        '''Remove a value of name from the stack.'''
        if name not in self._stack:
            raise AttributeError
        del self._stack[name][-1]
        if not self._stack[name]:
            del self._stack[name]
   
    def depth(self, name):
        l = len(self._stack[name])
        if l:
            return l-1

    def previous(self, name):
        if len(self._stack[name]) > 1:
            return self._stack[name][-2]

    def __repr__(self):
        return repr(self._stack)



class TargetResolver(object):

    def main(self, handlers, default_namespace=None):
        assert handlers, "Need at least one static target to bootstrap"
        if not default_namespace:
            default_namespace = Name.fetch(handlers[0]).prefix
        execution_graph = ExecGraph(handlers, default_namespace)
        stack = ContextStack()
        self.run(execution_graph, stack)

    def run(self, execution_graph, context, args=[], kwds={}):
        log.debug('Target resolver starting with %s', execution_graph.execlist)
        target = execution_graph.nextTarget()
        if not kwds:
            kwds = Keywords()
        while target:
            log.note('Run: %s', target.name)
            assert isinstance(kwds, Keywords), lib.cn(kwds)
            context.generator = target.handler.func(
                            **self.select_kwds(target.handler.func, kwds))
            if not context.generator:
                log.warn("target %s did not return generator", target)
            else:
                for r in context.generator:
                    assert not args, "TODO: %s" % args
                    if isinstance(r, str):
                        pass
                    if res.iface.ITarget.providedBy(r):
                        if r.required:
                            execution_graph.require(target, r)
                            self.run(execution_graph, context, args=args, kwds=kwds)
                        else:
                            execution_graph.append(target, r)
                    elif isinstance(r, int):
                        if r == 0:
                            assert not execution_graph, '???'
                        sys.exit(r)
                    elif isinstance(r, Arguments):
                        if r:
                            log.warn("Ignored %s", r)
                        #args.extend(r)
                    elif isinstance(r, Targets):
                        for t in r:
                            assert isinstance(t, str), t
                            execution_graph.require(target, t)
                    elif isinstance(r, Keywords):
                        kwds.deep_update(r)
                    else:
                        log.warn("Ignored yield %r", r)
            del context.generator
            target = execution_graph.nextTarget()

    def select_kwds(self, func, kwds):
        func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
                inspect.getargspec(func)
#        assert func_arg_vars.pop(0) == 'self'
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



