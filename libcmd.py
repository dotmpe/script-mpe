"""
:Created: 2011-06-10

libcmd - a command-line program toolkit based on optparse (XXX: and yaml, zope?)

.. note::

    While too-ambitious-version is moved to libcmdng the simple command base-class
    version is reestablished here.

The goal is to easily bootstrap simple or complex command-line programs,
allowing custom code to run and to further extend the base program.

The SimpleCommand approach uses --command to set te 'handler' to run,
which (after opt-parsing) corresponds to a method on the SimpleCommand
or subclass.
Multiple handlers may run in sequence, take any selection of parameters,
can behave as generators or not, and can return something or not.

StackedCommand subclasses and adds a prefix to enable namespace sharing
to enable (multi?) inheritance of several different SimpleCommand subclasses
working together in one ore more static program frontend.
This has a second configuration source too do enable the sub-programs to have
local configuration, separated from other programs.

XXX: while under development, further explanation is given inline.

Wether any var in the function signature has a default does not matter,
XXX currently missing vars are padded with None values, perhaps a warning
"""
from __future__ import print_function
import inspect
import optparse
import os
from pprint import pformat
import sys
import traceback
import types
#from inspect import isgeneratorfunction
import collections

import zope.interface

from . import lib
from .taxus import iface, init
from . import log
from . import confparse
from confparse import Values


#@zope.interface.implementer(iface.IProgramHandlerResultProcessor)
class HandlerReturnAdapter(object):
    """
    Adapter return value/generator from handler back to program.

    This serves mostly to update globaldict,
    and if needed abstract the method of data return as used by SimpleCommand().execute()

    return_mode
        generates
            gen-{first,last,all}-key{,s}
        returns generated
            {first,last,all}-key{,s}

    """
    def __init__(self, globaldict):
        self.globaldict = globaldict
        self.generated = []
        self.set_return_mode(':')
    def set_return_mode( self, return_mode=None ):
        self.generates = return_mode.startswith( 'gen-' )
        return_mode.replace('gen-', '')
        self.retpref, self.retkey = return_mode.split(':')
        self.returns = self.retpref.split('-')[0] in [ 'first', 'last', 'all' ]
    def start( self, ret ):
        if isinstance(ret, int):
            sys.exit(ret) # XXX
        elif ret:
            assert isinstance(ret, types.GeneratorType), ret
            for r in ret:
                if isinstance(r, dict) or isinstance(r, confparse.Values):
                    self.update( r )
                    log.debug("Updating globaldict %r", r)
                    confparse.DictDeepUpdate.update( self.globaldict, r )
                else:
                    yield r
    def update( self, res ):
        if self.retpref == 'all-key':
            if self.retkey in res:
                self.generated.append( res )
        if self.retpref == 'first-key':
            if self.retkey in res:
                if not self.generated:
                    self.generated = res


@zope.interface.implementer(iface.IReporter)
#@zope.interface.implementer(iface.IFormatted)
class ResultFormatter(object):
    __used_for__ = iface.IReportable

    #__used_for__ = iface.IReportable, iface.

    def append(self, res):
        pass

    @property
    def buffered(self):
        pass

    def flush(self):
        pass


# Option Callbacks for optparse.OptionParser.

def optparse_override_quiet(option, optstr, value, parser):
    "Turn off non-essential output. "
    oldv = parser.values.message_level
    parser.values.quiet = True
    parser.values.interactive = False
    parser.values.message_level = 4 # skip warning and below
    log.debug("Verbosity changed from %s to %s", oldv, parser.values.message_level )

def optparse_print_help(options, optstr, value, parser):
    parser.print_help()

def optparse_increase_verbosity(option, optstr, value, parser):
    "Lower output-message threshold by increasing message level. "
    oldv = parser.values.message_level

    if parser.values.message_level == 0:
        log.warn( "Verbosity already at maximum. ")
        return
    #if not hasattr(parser.values, 'message_level'): # XXX: this seems to be a bug elsewhere
    #    parser.values.message_level = 0

    if parser.values.message_level:
        parser.values.message_level -= 1

    parser.values.quiet = False
    log.debug( "Verbosity changed from %s to %s", oldv, parser.values.message_level )


def optparse_set_handler_list(option, flagstr, value, parser, append=False,
        default=None, prefix=None):
    """
    Replace value at dest with list parsed from next argument
    if no default is given.

    If option not matches SimpleCommand.COMMAND_FLAG then instead
    the option is converted to a single handler_name
    (If no default is given).

    `append` enables subsequent flags to extend the existing list
    value.
    """
    if flagstr in SimpleCommand.COMMAND_FLAG:
        new_values = parser.rargs.pop().split(',')
    elif default:
        new_values = default
        assert isinstance( new_values, list ), new_values
    else: # convert long-opt flag to value
        p = prefix and prefix + '_' or ''
        longopt = option.get_opt_string().strip('-').replace('-','_')
        if not longopt.startswith(p):
            new_values = [ p + longopt ]
        else:
            new_values = [ longopt ]
    old_values = getattr( parser.values, option.dest )
    if append:
        values = old_values
        values.extend(new_values)
    else:
        values = new_values
    setattr( parser.values, option.dest, values )
    log.debug('optparse: %s changed %s from %s to %s',
            flagstr, option.dest, old_values, values)

# shortcut for setting command from 'handler flags'
def cmddict(prefix=None, append=None, default=None, **override):
    d = dict(
            action='callback',
            dest='commands',
            callback=optparse_set_handler_list,
            # append, default, prefix:
            callback_args=(append, default, prefix)
        )
    d.update(override)
    return d


class StaticContext(object):

    """
    IStaticContext - specify some of the static environment for the program to
    initialize from
    """

    def __init__(self, inheritor ):
        """
        Given a Class XXX implementing ISimpleCommand
        and a working directory.
        """
        self.inheritor = inheritor

    def getname(self):
        "Return the name for the program currently run. "
        if hasattr(self.inheritor, 'NAME'):
            return self.inheritor.NAME
        else:
            return os.path.splitext(os.path.basename(__file__))[0]
    name = property( getname )

    def getpwd(self):
        return os.getcwd()
    pwd = property( getpwd )

    def __str__(self):
        "%s at %s" % ( self.inheritor, self.pwd )


class ConfigSpec(object):
    "Helper for XXX recursive system- and user-config file locations and formats. "
    def __init__( self, staticcontext ):
        pathiter = confparse.find_config_path(
                staticcontext.name, staticcontext.pwd )

    """
    TODO: combine  find_config_path
    """

class SimpleCommand(object):

    """
    Helper base-class for command-line functions.
    XXX Perhaps generalize to use optionspecs without command-line-style
    parsing but for specification and validation only.
    XXX also, looking for more generic way to invoke subcommands, without
    resorting to cmddict.
    """
    """
    currently
        static_args: prog.name => prog.{pwdspec, configspec, optspec}
        load_config:  prog.{pwdspec, configspec} => settings, rc, prog.{config}
        cmd_options:  prog.optspec => args, opts + globaldict

        --save-user-config
    """

    # optparse vars: prog name, version and short usage descr.
    NAME = 'libcmd'
    PROG_NAME = os.path.splitext(os.path.basename(sys.modules['__main__'].__file__))[0]
    VERSION = "0.1"
    USAGE = """Usage: %prog [options] paths """

    OPTS_INHERIT = ( '-v', )
    COMMAND_FLAG = ('-C', '--command')

    BOOTSTRAP = [ 'static_args', 'parse_options', 'load_config', 'prepare_output', 'set_commands' ]
    DEFAULT = [ 'stat', ]

    DEFAULT_RC = 'libcmdrc'
    DEFAULT_CONFIG_KEY = NAME
    INIT_RC = None

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.

        XXX: cannot stuff away options at StackedCommand, need to solve some
          issues at SimpleCommand.
        StackedCommand will prefix flags from the higher classes, keeping the
        entire name-space free for the subclass to fill. --cmd-list vs. --list
        FIXME: what todo upon conflicts. better solve this explicitly i think?
            so the inheritor needs to override local behaviour
            perhaps inheritor.get_optspec_override can return its options
            and locally these are prefixed

        StackedCommand defines a flag-prefixer that should be used in get_optspec
        implementations when the current Klass is not the same as the inheritor.
        The SimpleCommand.get_optspec does the same and it ensures the entire
        flag namespace is free for the subclass to use.

        SimpleCommand defines a dummy flag-prefixer.

        The inheritor can redefine or inherit get_prefixer, inheritor.get_prefixer
        should be used to get it. And so it goes with all static properties to
        allow for overrides. There is no option to leave out an option.
        """
        p = inheritor.get_prefixer(Klass)
        return (
            p(inheritor.COMMAND_FLAG, { 'metavar':'ID',
                'help': "Action (default: %default). ",
                'dest': 'commands',
                'action': 'callback',
                'callback': optparse_set_handler_list,
                'default': inheritor.DEFAULT
            }),
            # XXX: is this reserved for names to be used with confparse path
            # scan, or can it have full paths too.. currently it is just a name
            p(('-c', '--config',),{ 'metavar':'NAME',
                'dest': "config_file",
                'default': inheritor.DEFAULT_RC,
                'help': "Run time configuration. This is loaded after parsing command "
                    "line options, non-default option values wil override persisted "
                    "values (see --update-config) (default: %default). " }),

            p(('-U', '--update-config',),{ 'action':'store_true', 'help': "Write back "
                "configuration after updating the settings with non-default option "
                "values.  This will lose any formatting and comments in the "
                "serialized configuration. ",
                'default': False }),

            p(('-K', '--config-key',),{ 'metavar':'ID',
                'dest': 'config_key',
                'default': inheritor.DEFAULT_CONFIG_KEY,
                'help': "Key to current program settings in config-file. Set "
                    "if only part of settings in config file are used. "
                    " (default: %default). " }),

#            p(('--init-config',),cmddict(help="runtime-configuration with default values. "
#                'dest': 'command',
#                'callback': optparse_override_handler }),
#
#            p(('--print-config',),{ 'action':'callback', 'help': "",
#                'dest': 'command',
#                'callback': optparse_override_handler }),

            p(('-i', '--interactive',),{ 'help': "Allows commands to run extra heuristics, e.g. for "
                "selection and entry that needs user supervision. Normally all options should "
                "be explicitly given or the command fails. This allows instead to use a readline"
                "UI during execution. ",
                'default': False,
                'action': 'store_true' }),

            p(('--continue','--non-interactive',),{
                'help': "Never prompt user, solve and continue or raise error. ",
                'dest': 'interactive',
                'default': False,
                'action': 'store_false' }),

            # FIXME see what happes with this later
            p(('-L', '--message-level',),{ 'metavar':'level',
                'dest': 'message_level',
                'help': "Increase chatter by lowering "
                    "message threshold. Overriden by --quiet or --verbose. "
                    "Levels are 0--7 (debug--emergency) with default of 2 (notice). "
                    "Others 1:info, 3:warning, 4:error, 5:alert, and 6:critical.",
                'default': 2,
            }),

            p(('-v', '--verbose',),{ 'help': "Increase chatter by lowering message "
                "threshold. Overriden by --quiet or --message-level.",
                'action': 'callback',
                'callback': optparse_increase_verbosity}),

            p(('-q', '--quiet',),{ 'help': "Turn off informal message (level<4) "
                "and prompts (--interactive). ",
                'dest': 'quiet',
                'default': False,
                'action': 'callback',
                'callback': optparse_override_quiet }),

                )

    @classmethod
    def check_helpstring(Klass, longopt, attrs):
        if not 'help' in attrs or not attrs['help']:
            cmd = longopt[2:].replace('-', '_')
            if hasattr( Klass, cmd ):
                attrs['help'] = getattr( Klass, cmd ).__doc__

    @classmethod
    def get_prefixer(Klass, context):
        "Return dummy optparse flag prefixer. "
        def add_option_prefix(optnames, attrs):
            if 'dest' in attrs and attrs['dest'] == 'commands':
                if len(optnames[0]) == 2:
                    longopt = optnames[1]
                else:
                    longopt = optnames[0]
                Klass.check_helpstring(longopt, attrs)
            return optnames, attrs
        return add_option_prefix

    @classmethod
    def main(Klass, argv=None, optionparser=None, result_adapter=None, default_reporter=None):

        self = Klass()
        self.globaldict = Values(dict(
            prog=Values(),
            opts=Values(),
            args=[] ))

        self.globaldict.prog.handlers = self.BOOTSTRAP
        for handler_name in self.resolve_handlers():
            target = handler_name.replace('_', ':', 1)
            log.debug("%s.main deferring to %s", lib.cn(self), target)
            self.execute( handler_name )
            log.info("%s.main returned from %s", lib.cn(self), target)

        return self

    def __init__(self):
        super(SimpleCommand, self).__init__()

        self.settings = Values()
        "Global settings, set to Values loaded from config_file. "

    def get_optspecs(self):
        """
        Collect all options for the current class if used as Main command.
        Should be implemented by each subclass independently.

        XXX: doing this at instance time allows it to further pre-configure the
        options before returning them, but nothing much is passed along right
        now.
        """
        # get bottom up inheritance list
        mro = list(self.__class__.mro())
        # reorder to yield options top-down
        mro.reverse()
        for k in mro:
            if hasattr(k, 'get_optspec'):
                # that MRO Class actually defines get_optspec without inheriting it
                assert 'get_optspec' in k.__dict__, \
                        "SimpleCommand subclass must override get_optspec"
                yield k, k.get_optspec(self.__class__)

    def parse_argv(self, options, argv, usage, version):
        """
        Given the option spec and argument vector,
        parse it into a dictionary and a list of arguments.
        Uses Python standard library (OptionParser).
        Returns a tuple of the parser and option-values instances,
        and a list left-over arguments.
        """
        # TODO: rewrite to cllct.oslibcmd_docopt once that is packaged
        parser = optparse.OptionParser(usage, version=version)

        optnames = []
        nullable = []
        classdict = {}
        for klass, optspec in options:
            if hasattr(klass, 'get_opt_prefix'):
                prefix = klass.get_opt_prefix()
            else:
                prefix = 'cmd'
            classdict[ prefix ] = klass, optspec
            for optnames, optattr in optspec:
                try:
                    opt = parser.add_option(*optnames, **optattr)
                except Exception as e:
                    print("Error adding optspec %r to parser from %r: %s" % (
                            (optnames,optattr), klass, e))
                    traceback.print_exc()

        optsv, args = parser.parse_args(argv)

        #return parser, optsv, args

        # superficially move options from their confparse.Values object
        optsd = {}
        for name in dir(optsv):
            v = getattr(optsv, name)
            if not name.startswith('_') and not isinstance(v, collections.Callable):
                optsd[name] = v

        return parser, optsd, args

    def resolve_handlers( self ):
        """
        XXX
        """
        while self.globaldict.prog.handlers:
            o = self.globaldict.prog.handlers.pop(0)
            if hasattr(self, 'get_opt_prefix'):
                p = '%s_' % self.get_opt_prefix(self)
            else:
                p = self.DEFAULT_CONFIG_KEY or self.NAME
            yield o.startswith(p) and o.replace( p, '' ) or o

    def execute( self, handler_name, update={}, return_mode=None ):
        """
        During program execution this will call the individual handlers.
        It is called from execute program for every target and dependency,
        and can be called by handlers themselves.

        For each handler, the implements resolving variable names from the
        function signature to runtime values XXX IProgramHandler,
        and processing of the returned
        arguments with the help of IProgramHandlerResultProc.

        The return is always integreated with the current XXX IProgram

        return_mode specifies how the handler return value is processed
        by the result adapter.

        Currently the 'first:' prefix determines that the first named
        keywords is to be `return`\ 'ed. XXX: It should offer various
        methods of filter and either generate, return or be silent.

        """
        log.debug("SimpleCommand.execute %s %s", handler_name, update)
        if update:
            self.globaldict.update(update)
        handler = getattr( self, handler_name )
        args, kwds = self.select_kwds(handler, self.globaldict)
        log.debug("SimpleCommand.execute %s, %r, %r", handler.__name__,
                repr(args), repr(kwds))
        try:
            ret = handler(*args, **kwds)
        except Exception as e:
            log.crit("Exception in handler %s: %s", handler_name, e)
            traceback.print_exc()
            raise e
        # XXX:
        result_adapter = HandlerReturnAdapter( self.globaldict )
        #if isinstance( result_adapter, str ):
        #    result_adapter = getUtility(IResultAdapter, name=result_adapter)
        if return_mode:
            result_adapter.set_return_mode( return_mode )
        g = result_adapter.start( ret )
        if result_adapter.generates:
            return g
        for res in g:
            # XXX extracted.append(res)
            for reporter in self.globaldict.prog.output:
                reporter.append(res)
        if result_adapter.returns:
            return result_adapter.generated

    def select_kwds(self, handler, globaldict):
        """
        select values to feed a handler from the opts and args passed from the
        command line, and given a global dictionary to look up names from.

        see pyfuncsig.py for some practical info.
        """
        func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
                inspect.getargspec(handler)
        assert func_arg_vars, \
                "Command handler %s is missing 'self' argument. " % handler
        assert func_arg_vars.pop(0) == 'self', \
                "Expected a method %s" % handler
        #  initialize the two return values
        ret_args, ret_kwds = [], {}
        if not ( func_arg_vars or func_args_var or func_kwds_var or func_defaults):
            return ret_args, ret_kwds
        if func_defaults:
            func_defaults = list(func_defaults)
        # remember which args we have in ret_args
        pos_args = []
        #log.debug(pformat(dict(handler=handler, inspect=dict(
        #    func_arg_vars = func_arg_vars,
        #    func_args_var = func_args_var,
        #    func_kwds_var = func_kwds_var,
        #    func_defaults = func_defaults
        #))))
        # gobble first positions if present from args
        while func_arg_vars \
                and len(func_arg_vars) > ( func_defaults and len(func_defaults) or 0 ):
            arg_name = func_arg_vars.pop(0)
            if arg_name in globaldict:
                value = globaldict[arg_name]
            elif globaldict.args:
                value = globaldict.args.pop(0)
            else:
                value = None
            pos_args.append(arg_name)
            ret_args.append(value)
        # add all positions with a default
        while func_defaults:
            arg_name = func_arg_vars.pop(0)
            value = func_defaults.pop(0)
            if hasattr(globaldict.opts, arg_name):
                value = getattr(globaldict.opts, arg_name)
            #if hasattr(self.settings, arg_name):
            #    value = getattr(self.settings, arg_name)
            elif arg_name in globaldict:
                value = globaldict[arg_name]
            #ret_kwds[arg_name] = value
            #print 'default to position', arg_name, value
            pos_args.append(arg_name)
            ret_args.append(value)
        # feed rest of args to arg pass-through if present
        if globaldict.args and func_args_var:
            ret_args.extend(globaldict.args)
            pos_args.extend('*'+func_args_var)
#        else:
#            print 'hiding args from %s' % handler, args
        # ret_kwds gets argnames missed, if there is kwds pass-through
        if func_kwds_var:
            for kwd, val in list(globaldict.items()):
                if kwd in pos_args:
                    continue
                ret_kwds[kwd] = value
        return ret_args, ret_kwds

    # Handlers

    def static_args( self ):
        argv = list(sys.argv)
        yield dict( prog = dict(
            pwd = lib.cmd('pwd').strip(), # because os.getcwd resolves links
            home = os.getenv('HOME'),
            name = argv.pop(0),
            argv = argv ) )
        #name=os.path.splitext(os.path.basename(__file__))[0],
        #version="0.1",
        init.configure_components()

    def parse_options( self, prog ):
        # XXX
        #if optionparser and isinstance( optionparser, str ):
        #    parser = getUtility(IOptionParser, name=optionparser)
        #elif optionparser:
        #    #assert provides IOptionParser
        #    parser = optionparser
        #else:
        #   parser.set_defaults( values )

        optspecs = self.get_optspecs()
        prog.optparser, opts, args = \
                self.parse_argv( optspecs, prog.argv, self.USAGE, self.VERSION )

        yield dict( opts=opts, args=args )

        # XXX iface.gsm.registerUtility(iface.IResultAdapter, HandlerReturnAdapter, 'default')
        iface.registerAdapter(ResultFormatter)

    def load_config(self, prog, opts):
        """
        Optionally find prog.config_file from opts.config_file,
        and load returning its dict.
        If set but path is non-existant, call self.INIT_RC if exists.
        """
        if self.INIT_RC and hasattr(self, self.INIT_RC):
            log.note("Using config %r", self.INIT_RC)
            self.default_rc = getattr(self, self.INIT_RC)(prog, opts)
        else:
            self.default_rc = dict()

        if 'config_file' not in opts or not opts.config_file:
            self.rc = self.default_rc
            log.err( "Nothing to load configuration from")

        else:
            # FIXME: init default config
                #print self.DEFAULT_RC, self.DEFAULT_CONFIG_KEY, self.INIT_RC

            prog.config_file = self.find_config_file(opts.config_file)
            self.load_config_( prog.config_file, opts )
            log.info("Loaded config %r", prog.config_file)
            yield dict(settings=self.settings)

    def find_config_file(self, rc):
        rcfile = list(confparse.expand_config_path(rc))
        config_file = None
        if rcfile:
            config_file = rcfile.pop()
        # FIXME :if not config_file:
        assert config_file, \
                "Missing config-file for %s, perhaps use init_config_file" %( rc, )
        assert isinstance(config_file, str), config_file
        assert os.path.exists(config_file), \
                "Missing %s, perhaps use init_config_file"%config_file
        return config_file

    def load_config_(self, config_file, opts=None ):
        settings = confparse.load_path(config_file)

        config_key = opts.config_key
        if not config_key:
            self.rc = 'global'
            self.settings.update(settings)
            return

        if hasattr(settings, config_key):
            self.rc = self.default_rc
            if getattr(settings, config_key):
                self.rc.update(getattr(settings, config_key))
            self.rc.update({ k: v for k, v in opts.items() if v })
        else:
            log.warn("Config key %s does not exist in %s" % (config_key,
                config_file))

        settings.set_source_key('config_file')
        settings.config_file = config_file
        self.config_key = config_key
        self.settings.update(settings)

    def prepare_output( self, prog, opts ):
# XXX
        default_reporter = ResultFormatter()
        #if isinstance( default_reporter, str ):
        #    self.globaldict.prog.default_reporter_name = default_reporter
        #    default_reporter = getUtility(IReporter)
        #elif not default_reporter:
        #    default_reporter = self

        prog.output = [ default_reporter ]
        # XXX: opts.message_level should be an integer
        log.category = 7-int(opts.message_level)
        #print 'log level', log.category

        import taxus.core
        import taxus.net
        import taxus.model
        prog.module = (
                ( iface.INode, taxus.core.Node ),
                #( iface.IGroupNode, taxus.core.GroupNode ),
                ( iface.ILocator, taxus.net.Locator ),
                ( iface.IBookmark, taxus.model.Bookmark ),
            )
        #zope.interface.classImplements(prog, iface.IProgram)

    def path_args(self, prog, opts):
        """
        XXX this yields an args=[path] for each path arg,
        can this filter combined with parse_options..
        """
        for a in prog.argv[1:]:
            if os.path.exists(a):
                yield dict( args = [ a ] )
            else:
                log.warn("Ignored non-path argument %s", a)

    def set_commands(self, prog, opts):
        " Copy opts.commands to prog.handlers. "
        if opts and opts.commands:
            prog.handlers += opts.commands
        else:
            prog.handlers += self.DEFAULT
        log.debug("Initial commands are %s", repr(prog.handlers))

# TODO: post-deps
    def flush_reporters(self):
        for reporter in self.globaldict.prog.output:
            reporter.flush()

    def help(self, parser, opts, args):
        print("""
        libcmd.Cmd.help
        """)

    def stat(self, opts=None, args=None):
        if not self.rc:
            log.err("Missing run-com for %s", self.NAME)
        elif not self.rc['version']:
            log.err("Missing version for run-com")
        elif self.VERSION != self.rc['version']:
            if self.VERSION > self.rc['version']:
                log.err("Run com requires upgrade")
            else:
                log.err("Run com version mismatch: %s vs %s", self.rc['version'],
                        self.VERSION)
        print('args:', args)
        print('opts:', pformat(opts.todict()))


class StackedCommand(SimpleCommand):

    """
    SimpleCommand runs a handler sequence without further resolving,
    this subclass adds some simple dependency declarations.

    The point is that while SimpleCommand is meant to build ones own
    --command based program, StackedCommand recognizes that several such
    program classes should have a way to share the command-line options
    namespace. With the further addition of dependency resolving
    a stacked program structure can be build with increasing complexity,
    sharing code and/or having seperate frontends where appropiate or
    just convenient throught the development process.
    """

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    DEFAULT_RC = NAME+'rc'
    OPTS_INHERIT = '-v', '-q', '-i', '--message-level', '--continue', '--config'
    HANDLERS = [
#            'cmd:static', # collect (semi)-static settings
#            'cmd:config', # load (user) configuration
#            'cmd:options', # parse (user) command-line arguments
#                # to set and override settings, and get one or more targets
#            'cmd:actions', # run targets
        ]

    DEPENDS = {
            'static_args': [],
            'parse_options': ['static_args'],
            'load_config': ['parse_options'],
            'prepare_output': ['load_config'],
            'set_commands': ['prepare_output'],

#            'static_init': ['static_args'],
#            'load_config': ['static_init'],
            'print_config': ['load_config'],
        }

    ""
    # StackedCommand default bootstrap handlers
    # XXX because StackedCommand has dependency resolving it only lists the last
#    BOOTSTRAP = [ 'static_args', 'static_init', 'parse_options', 'load_config',
#        'prepare_output', 'set_commands' ]
    BOOTSTRAP = [ 'set_commands' ]
    DEFAULT = [ 'print_config' ]


    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (

        )

    @classmethod
    def get_opt_prefix(Klass):
        if hasattr( Klass, 'OPT_PREFIX' ):
            return Klass.OPT_PREFIX
        return Klass.NAME

    @classmethod
    def get_prefixer(Klass, context):
        def add_option_prefix(optnames, attrs):
            # excempt some options from prefixing filter
            for opt in optnames:
                if opt in Klass.OPTS_INHERIT:
                    return optnames, attrs
            # prepare prefixed option and dest
            if len(optnames[0]) == 2:
                longopt = optnames[1]
            else:
                longopt = optnames[0]
            assert longopt.startswith('--')
            if hasattr(context, 'get_opt_prefix'): # ignore SimpleCommand
                newlongopt = '--' + context.get_opt_prefix() + longopt[1:]
            else:
                # no prefix
                return optnames, attrs
            if 'dest' not in attrs:
                attrs['dest'] = newlongopt[2:].replace('-', '_')
            if attrs['dest'] == 'commands':
                Klass.check_helpstring(newlongopt, attrs)
            if Klass == context:
                return optnames, attrs
            else:
                return ( newlongopt, ), attrs
        return add_option_prefix

    def __init__(self):
        super(StackedCommand, self).__init__()

        self.rc = None
        "Runtime settings for this script. "

    def static_init(self):
        """
        Initializes the `prog` variable, determines its name and working
        directory and from there looks up all configuration files.

        Using the name it then sets up all command-line options.
        """

        # Set up a static name context
        inheritor = self.__class__
        static = StaticContext( inheritor )# XXX IStaticContext()
        yield dict( prog=dict( name = static ) )
        log.note('prog.name: %s', static)

        # Prepare a specification of the paths and types of configuration files
        configspec = ConfigSpec( static )# XXX ISimpleConfigSpec(config_file)
        yield dict( prog=dict( configspec = configspec ) )
        log.note('prog.configspec: %s', configspec)

        # Lastly also aggragate all options defined on the inheritance chain
        optspec = SimpleCommand.get_optspec( inheritor )
        yield dict( prog=dict( optspec = optspec ) )
        log.note('prog.optspec: %s', optspec)

    def resolve_handlers(self):
        """
        Generator for .
        """
        if 'DEPS' not in self.__dict__:
            self.DEPS = {}
            for k in self.__class__.mro():
                if 'DEPENDS' not in k.__dict__:
                    continue
                self.DEPS.update(k.DEPENDS)
        executed = []
        def recurse(name):
            depnames = self.DEPS[name]
            for dep in depnames:
                if dep not in executed:
                    log.debug("Found dependency for %s: %s", name, dep)
                    if dep in self.DEPS:
                        for x in recurse(dep):
                            yield x
                    else:
                        if name not in executed:
                            yield dep
                            executed.append( dep )
                        log.debug("Executed dependency %s", dep)
            if name not in executed:
                yield name
                executed.append( name )
            log.debug("Executed handler %s", name)

        while self.globaldict.prog.handlers:
            name = self.globaldict.prog.handlers.pop(0)
            if name not in self.DEPS:
                log.warn("No dependencies declared for %s", name)
                continue
            for x in recurse(name):
                yield x


# XXX
    def init_config_file(self):
        pass
    def init_config_submod(self):
        pass

    def init_config(self, **opts):
        config_key = self.NAME
        # Create if needed and load config file
        if self.settings.config_file:
            config_file = self.settings.config_file
        #elif self != self.getsource():
        #    config_file = os.path.join(os.path.expanduser('~'), '.'+self.DEFAULT_RC)

        if not os.path.exists(config_file):
            os.mknod(config_file)
            settings = confparse.load_path(config_file)
            settings.set_source_key('config_file')
            settings.config_file = config_file

        # Reset sub-Values of settings, or use settings itself
        if config_key:
            setattr(settings, config_key, Values())
            rc = getattr(settings, config_key)
        assert config_key
        assert isinstance(rc, Values)
        #else:
        #    rc = settings

        assert False, 'TODO update iso reset settings'
        self.settings = settings
        self.rc = rc

        self.init_config_defaults()

        v = input("Write new config to %s? [Yn]" % settings.getsource().config_file)
        if not v.strip() or v.lower().strip() == 'y':
            settings.commit()
            print("File rewritten. ")
        else:
            print("Not writing file. ")

    def init_config_defaults(self):
        self.rc.version = self.VERSION

    def update_config(self):
        #if not self.rc.root == self.settings:
        #    self.settings.
        if not self.rc.version or self.rc.version != self.VERSION:
            self.rc.version = self.VERSION;
        self.rc.commit()

    def print_config(self, config_file=None, **opts):
        #rcfile = list(confparse.expand_config_path(name))
        #print name, rcfile
        print(">>> libcmd.Cmd.print_config(config_file=%r, **%r)" % (config_file,
                opts))
        print('# self.settings =', self.settings)
        if self.rc:
            print('# self.rc =',self.rc)
            print('# self.rc.parent =', self.rc.parent)
        if 'config_file' in self.settings:
            print('# self.settings.config_file =', self.settings.config_file)
        if self.rc:
            confparse.yaml_dump(self.rc.copy(), sys.stdout)
        return False
