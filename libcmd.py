"""
While too-ambitious-version is moved to libcmdng the simple command base-class
version is reestablished here. 

The goal is to easily bootstrap simple or complex command-line programs,
allowing custom code to run and extend the base program.

The SimpleCommand approach uses --command to set te 'handler' to run,
multiple handlers run in sequence and behave as generators.

New keyword selection is more simple.
Everything libcmd does is kept on `prog`,
and there are `args` and `opts`.
XXX and later `settings` or `config`.

The lookup is entirely based on matching names,
starting with `globaldict` iow. the root, and then from `opts` and `args`.

Wether any var in the function signature has a default does not matter,
XXX currently missing vars are padded with None values, perhaps a warning 

The handlers themselves yield a dict to update the global dict
`prog` and add new names.
FIXME Yielding a list would indicate arguments that are handled and can be removed.
"""
import inspect
import optparse
import os
from pprint import pformat
import sys
#from inspect import isgeneratorfunction

import zope.interface

from taxus import iface, init
import log
import confparse
from confparse import Values


class HandlerReturnAdapter(object):
    #zope.interface.implements(iface.IResultAdapter)

    def __init__(self, globaldict):
        self.globaldict = globaldict
    def run( self, ret):
        if isinstance(ret, int):
            #log.warn(ret)
            sys.exit(ret)
        elif ret:
            for r in ret:
                if isinstance(r, dict) or isinstance(r, confparse.Values):
                    log.debug("Updating globaldict %r", r)
                    confparse.DictDeepUpdate.update( self.globaldict, r )
                else:
                    yield r

class ResultFormatter(object):
    zope.interface.implements(iface.IReporter)
    __used_for__ = iface.IReportable

    #zope.interface.implements(iface.IFormatted)
    #__used_for__ = iface.IReportable, iface.

    def append(self, res):
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
    parser.values.quiet = False
    if parser.values.message_level == 7:
        log.warn( "Verbosity already at maximum. ")
        return
    #if not hasattr(parser.values, 'message_level'): # XXX: this seems to be a bug elsewhere
    #    parser.values.message_level = 0 
    if parser.values.message_level:
        parser.values.message_level += 1
    log.debug( "Verbosity changed from %s to %s", oldv, parser.values.message_level )

def optparse_override_handler(option, optstr, value, parser, new_value):
    """
    Override value of `option.dest`.
    If no new_value given, the option string is converted and used.
    """
    assert not value
    if new_value:
        value = new_value
    else:
        value = option.get_opt_string().strip('-').replace('-','_')
    values = parser.values
    dest = option.dest
    setattr(values, dest, value)


# shortcut for setting command from 'handler flags'
def cmddict(**override):
    d = dict(
            action='callback',
            dest='command',
            callback=optparse_override_handler,
            callback_args=(None,) # default value is option name with '-' to '_'
        )
    d.update(override)
    return d


class SimpleCommand(object):

    """
    Helper base-class for command-line functions.
    XXX Perhaps generalize to use optionspecs without command-line-style
    parsing but for specification and validation only.
    XXX also, looking for more generic way to invoke subcommands, without
    resorting to cmddict.
    """

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    VERSION = "0.1"
    
    USAGE = """Usage: %prog [options] paths """

# TODO: restore here
    DEFAULT_RC = 'cllct.rc'
    DEFAULT_CONFIG_KEY = NAME

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
            (('-C', '--command'),{ 'metavar':'ID', 
                'help': "Action (default: %default). ", 
                'default': inherit.DEFAULT_ACTION }),
    
            (('-m', '--message-level',),{ 'metavar':'level',
                'help': "Increase chatter by lowering "
                    "message threshold. Overriden by --quiet or --verbose. "
                    "Levels are 0--7 (debug--emergency) with default of 2 (notice). "
                    "Others 1:info, 3:warning, 4:error, 5:alert, and 6:critical.",
                'default': 2,
            }),
   
            (('-v', '--verbose',),{ 'help': "Increase chatter by lowering message "
                "threshold. Overriden by --quiet or --message-level.",
                'action': 'callback',
                'callback': optparse_increase_verbosity}),
    
#            (('-Q', '--quiet',),{ 'help': "Turn off informal message (level<4) "
#                "and prompts (--interactive). ", 
#                'dest': 'quiet', 
#                'default': False,
#                'action': 'callback',
#                'callback': optparse_override_quiet }),

                )
    
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

    def __init__(self):
        super(SimpleCommand, self).__init__()
        self.globaldict = Values(dict( prog=Values(), ))

    def parse_argv(self, options, argv, usage, version):
        """
        Given the option spec and argument vector,
        parse it into a dictionary and a list of arguments.
        Uses Python standard library (OptionParser).
        Returns a tuple of the parser and option-values instances,
        and a list left-over arguments.
        """
        # TODO: rewrite to cllct.osutil once that is packaged
        #parser, opts, paths = parse_argv_split(
        #        self.OPTIONS, argv, self.USAGE, self.VERSION)

        parser = optparse.OptionParser(usage, version=version)

        optnames = []
        nullable = []
        for klass, optspec in options:
            for opt in optspec:
                try:
                    parser.add_option(*opt[0], **opt[1])
                except Exception, e:
                    print klass, e

        optsv, args = parser.parse_args(argv)

        # superficially move options from their Values object
        optsd = {}
        for name in dir(optsv):
            v = getattr(optsv, name)
            if not name.startswith('_') and not callable(v):
                optsd[name] = v

        return parser, optsv, optsd, args

    def main_option_overrides(self, parser, opts):
        """
        Update settings from values from parsed options. Use --update-config to 
        write them to disk.
        """
# XXX:
        #for o in opts.keys():
        #    if o in self.TRANSIENT_OPTS: # opt-key does not indicate setting
        #        continue
        #    elif hasattr(self.settings, o):
        #        setattr(self.settings, o, opts[o])
        #    elif hasattr(self.rc, o):
        #        setattr(self.rc, o, opts[o])
        #    else:
        #        err("Ignored option override for %s: %s", self.settings.config_file, o)

    def prepare_program( self, argv, optionparser ):
        """
        Program.main step 1.
        """
        globaldict = self.globaldict

        if not argv:
            argv = sys.argv
        globaldict.prog.name = argv.pop(0)
        globaldict.prog.argv = argv

        if isinstance( optionparser, basestring ):
            parser = getUtility(IOptionParser, name=optionparser)
        elif optionparser:
        # XXX
            #assert provides IOptionParser
            parser = optionparser
        else:
            parser = self

        #parser.set_defaults( values )

        globaldict.prog.optparser, globaldict.opts, kwds_, globaldict.args = \
                parser.parse_argv( self.get_optspecs(), argv, self.USAGE, self.VERSION )

        # XXX iface.gsm.registerUtility(iface.IResultAdapter, HandlerReturnAdapter, 'default')
        iface.registerAdapter(ResultFormatter)

    def prepare_output( self, default_reporter ):
        """
        Program.main step 2.
        """
# XXX
        default_reporter = ResultFormatter()
        #if isinstance( default_reporter, basestring ):
        #    self.globaldict.prog.default_reporter_name = default_reporter
        #    default_reporter = getUtility(IReporter)
        #elif not default_reporter:
        #    default_reporter = self

        self.globaldict.prog.output = [ default_reporter ]
        log.category = self.globaldict.opts.message_level

    def execute_program( self, result_adapter ):
        """
        Program.main step 3.
        """
        handler = getattr(self, self.globaldict.opts.command)
        self.execute( handler )
        for reporter in self.globaldict.prog.output:
            reporter.flush()

    def execute( self, handler, update={} ):
        """
        Called from execute program. Handlers can themselves call execute to
        correctly wrap keyword-selection and retun-generator handling.
        XXX: perhaps yield or something for use by handlers..
        """
        if update:
            self.globaldict.update(update)
        args, kwds = self.select_kwds(handler, self.globaldict)
        ret = handler(*args, **kwds)
        # XXX:
        result_adapter = HandlerReturnAdapter( self.globaldict )
        #if isinstance( result_adapter, basestring ):
        #    result_adapter = getUtility(IResultAdapter, name=result_adapter)
        for res in result_adapter.run( ret ):
            for reporter in self.globaldict.prog.output:
                reporter.append(res)

    @classmethod
    def main(Klass, argv=None, optionparser=None, result_adapter=None, default_reporter=None):
        """
        Run cmmdline parser and end one handler.
        TODO: rewrite to one command target, see main.py and TargetResolver.
        But work out concrete subcommands first. Pragmatic approach to
        understand requirements better before jumping in, and time to write
        auxiliary stuff. 
        """

        init.configure_components()

        self = Klass()
        self.prepare_program( argv, optionparser )
        self.prepare_output( default_reporter )
        self.execute_program( result_adapter )

        return self

    def select_kwds(self, handler, globaldict):
        """
        select values to feed a handler from the opts and args passed from the
        command line, and given a global dictionary to look up names from.

        see pyfuncsig.py for some practical info.
        """
        func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
                inspect.getargspec(handler)
        assert func_arg_vars.pop(0) == 'self', "Expected a method %s" % handler
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
            for kwd, val in globaldict.items():
                if kwd in pos_args:
                    continue
                ret_kwds[kwd] = value
        # XXX: internals to kwds
        #if "opts" in ret_kwds:
        #    ret_kwds['opts'] = globaldict.opts
        #if "args" in ret_kwds:
        #    ret_kwds['args'] = globaldict.args
        return ret_args, ret_kwds

# XXX cmd_actions?
    def cmd_actions(self, opts=None, **kwds):
        err("Cmd: Running actions")
        actions = [opts.command]
        while actions:
            actionId = actions.pop(0)
            action = getattr(self, actionId)
            assert callable(action), (action, actionId)
            err("Notice: running %s", actionId)
            #arg_list, kwd_dict = self.main_prepare_kwds(action, opts, [])#args)
            arg_list, kwd_dict = self.select_kwds(action, globaldict)
            ret = action(**kwd_dict)
            #print actionId, adaptable.IFormatted(ret)
            if isinstance(ret, tuple):
                action, prio = ret
                assert isinstance(action, str)
                if prio == -1:
                    actions.insert(0, action)
                elif prio == sys.maxint:
                    action.append(action)
                else:
                    action.insert(prio, action)
            else:
                if not ret:
                    ret = 0
                #if isinstance(ret, int) or isinstance(ret, str) and ret.isdigit(ret):
                #    sys.exit(ret)
                #elif isinstance(ret, str):
                #    err(ret)
                #    sys.exit(1)

    def get_config_file(self):
        rcfile = list(confparse.expand_config_path(self.DEFAULT_RC))
        if rcfile:
            config_file = rcfile.pop()
        else:
            config_file = self.DEFAULT_RC
        "Configuration filename."

        if not os.path.exists(config_file):
            assert False, "Missing %s, perhaps use init_config_file"%config_file
        
        return config_file

    def load_config(self, config_file, config_key=None):
        settings = confparse.load_path(config_file)
        settings.set_source_key('config_file')
        settings.config_file = config_file
        if not config_key:
            config_key = self.NAME
        if hasattr(settings, config_key):
            self.rc = getattr(settings, config_key)
        else:
            raise Exception("Config key %s does not exist in %s" % (config_key,
                config_file))
        self.config_key = config_key
        self.settings = settings

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

        self.settings = settings
        self.rc = rc

        self.init_config_defaults()

        v = raw_input("Write new config to %s? [Yn]" % settings.getsource().config_file)
        if not v.strip() or v.lower().strip() == 'y':
            settings.commit()
            print "File rewritten. "
        else:
            print "Not writing file. "

    def init_config_defaults(self):
        self.rc.version = self.VERSION

    def update_config(self):
        #if not self.rc.root == self.settings:
        #    self.settings.
        if not self.rc.version or self.rc.version != self.VERSION:
            self.rc.version = self.VERSION;
        self.rc.commit()

    def print_config(self, config_file=None, **opts):
        print ">>> libcmd.Cmd.print_config(config_file=%r, **%r)" % (config_file,
                opts)
        print '# self.settings =', self.settings
        if self.rc:
            print '# self.rc =',self.rc
            print '# self.rc.parent =', self.rc.parent
        if 'config_file' in self.settings:
            print '# self.settings.config_file =', self.settings.config_file
        if self.rc:
            confparse.yaml_dump(self.rc.copy(), sys.stdout)
        return False

    def get_config(self, name):
        rcfile = list(confparse.expand_config_path(name))
        print name, rcfile

    def stat(self, opts=None, args=None):
        if not self.rc:
            log.err("Missing run-com for %s", self.NAME)
        elif not self.rc.version:
            log.err("Missing version for run-com")
        elif self.VERSION != self.rc.version:
            if self.VERSION > self.rc.version:
                log.err("Run com requires upgrade")
            else:
                log.err("Run com version mismatch: %s vs %s", self.rc.version,
                        self.VERSION)
        print args, opts

    def help(self, parser, opts, args):
        print """
        libcmd.Cmd.help
        """


class StackedCommand(SimpleCommand):

    """
    Simple command should get a clean up.
    This should start to do dependencies.
    """

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        # No further static init, just return global
        return (
            (('-c', '--config',),{ 'metavar':'NAME', 
                'dest': "config_file",
                'default': inherit.DEFAULT_RC, 
                'help': "Run time configuration. This is loaded after parsing command "
                    "line options, non-default option values wil override persisted "
                    "values (see --update-config) (default: %default). " }),

            (('-K', '--config-key',),{ 'metavar':'ID', 
                'default': inherit.DEFAULT_CONFIG_KEY, 
                'help': "Settings root node for run time configuration. "
                    " (default: %default). " }),

            (('-U', '--update-config',),{ 'action':'store_true', 'help': "Write back "
                "configuration after updating the settings with non-default option "
                "values.  This will lose any formatting and comments in the "
                "serialized configuration. ",
                'default': False }),

            (('--interactive',),{ 'help': "Allows commands to run extra heuristics, e.g. for "
                "selection and entry that needs user supervision. Normally all options should "
                "be explicitly given or the command fails. This allows instead to use a readline"
                "UI during execution. ",
                'default': False,
                'action': 'store_true' }),

            (('--non-interactive',),{ 
                'help': "Never prompt, solve or raise error. ", 
                'dest': 'interactive', 
                'default': False,
                'action': 'store_false' }),

#            (('--init-config',),cmddict(help="runtime-configuration with default values. "
#                'dest': 'command', 
#                'callback': optparse_override_handler }),
#
#            (('--print-config',),{ 'action':'callback', 'help': "",
#                'dest': 'command', 
#                'callback': optparse_override_handler }),

        )


    HANDLERS = [
#            'cmd:static', # collect (semi)-static settings
#            'cmd:config', # load (user) configuration
#            'cmd:options', # parse (user) command-line arguments
#                # to set and override settings, and get one or more targets
#            'cmd:actions', # run targets
        ]

    DEPENDS = {
            'cmd_static': [],
            'cmd_config': ['cmd_static'],
            'cmd_options': ['cmd_config'],
        }

    "Options are divided into a couple of classes, unclassified keys are treated "
    "as rc settings. "
    TRANSIENT_OPTS = [
            'config_key', 'init_config', 'print_config', 'update_config',
            'command',
            'quiet', 'message_level',
            'interactive'
        ]
    ""
    DEFAULT_ACTION = 'print_config'

    def __init__(self):
        super(StackedCommand, self).__init__()
    
        self.settings = Values()
        "Global settings, set to Values loaded from config_file. "

        self.rc = None
        "Runtime settings for this script. "

    def cmd_static(self):
        config_file = self.get_config_file()
        #self.settings.config_file = config_file
        yield dict(
                prog=dict( 
                    #name=self.NAME,
                    #cwd=os.getcwd(),
                    config_file=config_file))
        
    def cmd_config(self, prog):
        #    self.init_config() # case 1: 
        #        # file does not exist at all, init is automatic
        if not prog.config_file:
            log.err( "Nothing to load configuration from")
        else:
            #self.main_user_defaults()
            self.settings = confparse.load_path( prog.config_file )
            yield dict(settings=self.settings)

    def cmd_options(self, prog, opts):
        # XXX: perhaps restore shared config later
# XXX: options are alreay parsed. parse them here? like libcmdng
        # Get a reference to the RC; searches config_file for specific section
        config_key = self.DEFAULT_CONFIG_KEY
        if hasattr(opts, 'config_key') and opts.config_key:
            config_key = opts.config_key

        if not hasattr(self.settings, config_key):
            log.warn("Config file %s is missing config key for %s. ",
                    self.settings.config_file, config_key)
            if opts.command == 'init_config':
                self.init_config_submod()
            else:
                log.err("Config key must exist in %s ('%s'), use --init-config. ",
                    opts.config_file, opts.config_key)
                sys.exit(1)

        self.rc = getattr(self.settings, config_key)
        yield dict(rc=self.rc)

    def resolve_depends(self, name):
        """
        Create (and cache) one dict for dependencies.
        Return chain for given name.
        """
        if 'DEPS' not in self.__dict__:
            self.DEPS = {}
            for k in self.__class__.mro():
                if 'DEPENDS' not in k.__dict__:
                    continue
                self.DEPS.update(k.DEPENDS)
        names = [name]
        deps = []
        while names:
            name = names.pop()
            depnames = self.DEPS[name]
            [ names.append(dep) for dep in depnames if dep not in names ]
            deps.insert(0, name)
        return deps 

    def execute_program( self, result_adapter ):
        """
        Override for Program.run_program to run multiple dependent commands.
        """
        globaldict = self.globaldict
        handler_depends = self.resolve_depends(globaldict.opts.command)
        log.debug("Command %s resolved to handler list %r", globaldict.opts.command,
                handler_depends)
        for handler_name in handler_depends:
            log.info("StackedCommand.main: deferring to %s", handler_name)
            handler = getattr(self, handler_name)
            self.execute( handler )



if __name__ == '__main__':
    SimpleCommand.main()

