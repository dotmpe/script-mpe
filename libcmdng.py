"""
libcmdng is an ongoing effort to built an command line scripting toolkit

old docs below.

libcmd is a library to handle command line invocations; parse them to flags,
options and commands, and validate, resolve prerequisites and execute.

Within this little framework, a command target is akin to a build-target in ant
or make alike buildsystems. In libcmd it is namespaced, and is more complex, but is
has prerequisites and other dependencies and yields certain results.

Example::

    $ cmd ns:target --option ns2:target argument

Mode of interpretation is (POSIX?) that there is a list of targets, one for arguments,
and a set of options, no order or context is imposed here on these different
elements. Iow. it is just interpreted as one set, not as an line of ordered
arguments. I'm playing the idea to create a more structured approach

    $ cmd --flag 123 :target --flag 321 :target2 :target3 --flag 456

Such that target2 gets flag=123 but target gets flag=321 and target1 flag=456.
Idk, I'll think about that.

XXX: Current implementation is very naive, just to get it working but when it
proves workable, better design and testing time is wanted.

Right now three main constructs are used to create custom command line programs
from a few routines. Routines are decorated Python functions, used as generator
ie. someting like coroutines perhaps idk but I love to use them.

Namespace.register
    - defines and returns a new namespace instance

Options.register
    - defined a set of options for a namespace.

Target.register
    - registers a routine as a new command target, with a namespace and local
      name, and arguments and a generator that correspond to certain specs.

Other types are Targets, Keywords and Arguments. These are yielded from the
custom command routines for var. purposes:

Targets
    Indicate dynamic prequisites. Static prequisites can be found at startup
    from the explicit declarations using Target.register, but dynamic
    dependencies cannot. XXX: this functionality probably needs review.
Keywords
    Provide a new keyword to the TargetResolver, to be passed to targets that
    require this property (ie. those commands depend on the command yielding this
    type). The function argument names of the routine declaration is used to
    match with these properties. XXX: namespaces are not used yet.
Arguments
    The same as Keywords but for positional, non-default argument names which
    are required for invocation.

Class overview:
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
        ..
    TargetResolver
        - main self, handlers
        - run self, execution_graph, context, reporter, argss[], kwds={}
        - select_kwds(self, func, kwds, args):

    OptionParser
        ..

"""
from __future__ import print_function
import sys
import inspect
import optparse
from UserDict import UserDict

import zope

import log
from reporter import Reporter
from libname import Name, Namespace
import confparse

import res
from res.iface import IName


class OptionParser(optparse.OptionParser):

    """
    Customized OptionParser prints all targets too on 'help'.
    """

    def __init__(self, usage, version=None):
        optparse.OptionParser.__init__(self, usage, version=version)
        self._targets = None

    def print_help(self, file=None):
        if file is None:
            file = sys.stdout
        encoding = self._get_encoding(file)
        file.write(self.format_help().encode(encoding, "replace"))
        log.info("%s options", len(self.option_list))
        file.write("\n")
        self.print_targets(fl=file)

    @property
    def targets(self):
        """
        Instance property for convenience.
        """
        if not self._targets:
            self._targets = list(Target.instances.keys())
            self._targets.sort()
        return self._targets

    def print_targets(self, fl=None):
        targets = self.targets
        fl.write("Targets: \n")
        for target in targets:
            fl.write('  -', target, "\n")
        fl.write(len(targets), 'targets\n')


class Handler(object):
    "Composite to hold func and prerequisites, nothing else. "
    def __init__(self, func=None, prerequisites=[], requires=[], results=[]):
        self.func = func
        self.prerequisites = prerequisites
#        self.requires = requires
#        self.results = results

# Command routine generator yield types


class Targets(tuple):
    def __init__(self, *args):
        self.required = False
        tuple.__init__(self, *args)
    def required(self):
        self.required = True
        return self
    def __str__(self):
        return 'targets'+tuple.__str__(self)


class Keywords(UserDict):
    def __init__(self, **kwds):
        UserDict.__init__(self)
        self.update(kwds)
    def __str__(self):
        return 'keywords %r' % self


class Arguments(tuple):
    def __str__(self):
        return 'arguments'+tuple.__str__(self)

#
class Options(UserDict):

    """
    Registry for option specs.
    """

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
    def register(klass, ns=None, *options):

        """
        Registers a standard list of options, compabible with optparse.
        """

        for opts, attrdict in options:

            klass.opts.append(opts)

            idx = len(klass.attributes)
            klass.attributes.append(attrdict)

            for opt in opts:
                assert opt not in klass.options
                klass.options[opt] = idx

            for key in 'metavar', 'dest':
                if key in attrdict:
                    varname = attrdict[key]
                    if varname not in klass.variables:
                        klass.variables[varname] = []
                    if idx not in klass.variables[varname]:
                        klass.variables[varname].append(idx)

    @classmethod
    def get_options(klass):
        option_spec = []
        for idx, opts in enumerate(klass.opts):
            attr = klass.attributes[idx]
            option_spec.append((opts, attr))
        return tuple(option_spec)


class ExecGraph(object):

    """
    This helps to model interdependencies of nodes in the execution tree,
    and should provide a session context for results generated by individual targets.
    Ie. result objects are linked to their original target execution context.

    It consists basically a graph of targets, dependencies and results broken down to
    triples, and an execution list.
    Upon construction, a set of root handlers is seeded into the execution list.

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

    def __init__(self, root=[]):
        # P(s,o) lookup map for target and results structure
        self.edges = type('Edges', (object,), dict(
                s_p={},
                s_o={},
                o_p={}
            ))
        self.commands = {}
        self.execlist = []
        self.pointer = 0
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
    def load(name):
        """
        Get the Target for name and create a Command and Handler instance
        for it.
        """
        assert isinstance(name, str)
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
                cmdtarget = ExecGraph.load(node)
                self.commands[cmdtarget.key] = cmdtarget
        else:
            # Use given node as command instance
            if not force and node.key in self.commands:
                raise KeyError("Key exists: %s" % node.key)
            self.commands[node.key] = node
        return self.commands[node]

    def name(self, node):
        if res.iface.ICommand.providedBy(node):
            node = node.key
        if res.iface.IName.providedBy(node):
            node = node.qname
        assert isinstance(node, str)
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
        idx = self.index(S_target)
        if O_name not in self.execlist:
            self.put(O_target, idx)
            O_target = self.instance(O_target)
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
        """
        """
        assert isinstance(target, str)
        if idx == -1:
            idx = len(self.execlist)
        assert idx >= 0, idx
        assert idx <= len(self.execlist), idx
        assert target in Target.handlers, "Unknown target name %s"% target
        # strip succeeding occurences of target in execlist
        while target in self.execlist:
            if self.index(target) > idx:
                self.execlist.remove(target)
            else:
                break
        # insert this target into execlist
        if target not in self.execlist:
            self.execlist.insert(idx, target)
        # assure the target node and dependencies are initialized
        target = self.instance(target)

    @property
    def current(self):
        "Return target at pointer, or none if execution list is exhausted. "
        if self.pointer >= 0 and self.pointer < len(self.execlist):
            return self.execlist[self.pointer]

    def __bool__(self):
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
        log.debug('ExecGraph: nextTarget is %i, %r %r'
                %(
                    self.pointer,
                    target.name,
                    self.execlist
                ))
        self.pointer += 1
        return target


class Target(object):

    """
    Helper class for functions registered as command handlers.
    This registers new handlers and holds the registory to look them up.
    """

    zope.interface.implements(res.iface.ITarget)

    def __init__(self, name, depends=[], handler=None, values={}):
        assert isinstance(name, Name), name
        self.name = name
        self.depends = list(depends)
        self.handler = handler
        self.values = values
        klass = self.__class__
        # auto static register
        if name.qname not in klass.instances:
            klass.instances[name.qname] = self
        else:
            log.warn("%s already in %s.instances", self, klass)

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
    def register(klass, ns, name, *depends):

        """
        Decorator to register a function to be used as command handler,
        identified by given namespace and localname.
        """

        assert ns.prefix in Namespace.prefixes \
                and Namespace.prefixes[ns.prefix] == ns.uriref
        handler_id = ns.prefix +':'+ name
        handler_name = Name.fetch(handler_id, ns=ns)
        assert handler_id not in klass.handlers, "Duplicate handler %s" % handler_id
        def decorate(handler):
            klass.handlers[handler_id] = klass(
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
    def fetch(klass, name):
        assert isinstance(name, Name), name
        assert name.name in klass.handlers
        return klass.handlers[name.name]


class Command(object):

    """
    Composite of a Handler and ExecGraph, along with a name.
    Used by ExecGraph.load(target-name)
    """

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

    """
    A stack of states. Setting an attribute overwrites the last
    value, but deleting the value reactivates the old one.
    Default values can be set on construction.
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

    """
    Simple abstract frontend for libcmdng.
    """

    def main(self, handlers):

        """
        This is the main handler.
        It prepares the ExecGraph, ContextStack and Reporter.
        TargetResolver.run is where the actual targets are executed.
        """

        assert handlers, "Need at least one static target to bootstrap"
        execution_graph = ExecGraph(handlers)
        stack = ContextStack()
        reporter = Reporter()
        self.run(execution_graph, stack, reporter)
        reporter.flush()

    def run(self, execution_graph, context, reporter, args=[], kwds={}):
        """
        execution_graph:ExecGraph
            ties command targets together as nodes in a
            network, expressing dependencies and other relations as typed edges.
        context:ContextStack  is an stack for multiple properties, where each
            property is stacked by attribute assignment and popped using 'del'.
            Used only for generator right now.
        args and kwds are argument vectors shared with all commands, updated and
            overriden from each command if needed
        """
        log.debug('Target resolver starting with %s', execution_graph.execlist)
        target = execution_graph.nextTarget()
        while target:
            log.note('Run: %s', target.name)
            assert isinstance(kwds, dict)
            # Execute Target Command routine (returns generator)
            context.generator = target.handler.func(
                            **self.select_kwds(target.handler.func, kwds, args))
            if not context.generator:
                log.warn("target %s did not return generator", target)
                # isgeneratorfunction(context.generator):
            else:
                # Handle results from Command
                for r in context.generator:
                    if isinstance(r, str):
                        pass # resolve something from string notation?
                    # post-exec subcommands..
                    if res.iface.ITarget.providedBy(r):
                        if r.required:
                            execution_graph.require(target, r)
                            self.run(execution_graph, context, reporter, args=args, kwds=kwds)
                        else:
                            execution_graph.append(target, r)
                    # push post-commands
                    elif isinstance(r, Targets):
                        for t in r:
                            execution_graph.require(target, t)
                    # replace argument vector
                    elif isinstance(r, Arguments):
                        #if r:
                        #    log.warn("Ignored %s", r)
                        args = r#args.extend(r)
                    # update keywords
                    elif isinstance(r, Keywords):
                        kwds.update(r)
                    # stop & set process return status bit
                    elif isinstance(r, int):
                        if r == 0:
                            assert not execution_graph, '???'
                        reporter.flush()
                        sys.exit(r)
                    # aggregate var. result data for reporting (to screen, log, ...)
                    elif res.iface.IReport.providedBy(r):
                        reporter.append(r)
                    elif res.iface.IReportable.providedBy(r):
                        reporter.append(r)
                    else:
                        log.warn("Ignored yield from %s: %r", target.name, r)
            del context.generator
            target = execution_graph.nextTarget()

    def select_kwds(self, func, kwds, args):
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

        if "opts" in ret_kwds:
            ret_kwds['opts'] = confparse.Values(kwds)
        if "args" in ret_kwds:
            ret_kwds['args'] = args

        return ret_kwds


