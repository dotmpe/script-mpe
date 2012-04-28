#!/usr/bin/env python
"""
Build on confparse module to create boostrapping for CL apps.

TODO: segment configuration, see confparse.
TODO: command line parser should not need before hand option specs;
  allow for run-time resolving of dependent component.


WIP, see libcmd2
- Configuration is composite of static config, system config and user config
- PersistedObject allows several indices of local objects storage, depends on Configuration
- 
- StatusCommand depends on 
- SQLStore depends on Configuration, 


"""
import inspect
import optparse
import os
import sys
from os.path import join, isdir

import confparse
import taxus_out as adaptable


settings = confparse.load('cllct.rc')
"Parse settings. "


def err(msg, *args):
    "Print error or other syslog notice. "
    print >> sys.stderr, msg % args


# Option Callbacks for optparse.OptionParser.

def optparse_decrement_message(option, optstr, value, parser):
    "Lower output-message threshold. "
    parser.values.quiet = False
    parser.values.messages -= 1

def optparse_override_quiet(option, optstr, value, parser):
    "Turn off non-essential output. "
    parser.values.quiet = True
    parser.values.interactive = False
    parser.values.messages = 4 # skip warning and below

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


# Main application

class Cmd(object):

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    VERSION = "0.1"

    USAGE = """Usage: %prog [options] paths """

    DEFAULT_RC = 'cllct.rc'
    DEFAULT_CONFIG_KEY = NAME

    @classmethod
    def get_opts(klass):
        return (
            (('-c', '--config',),{ 'metavar':'NAME', 
                'dest': "config_file",
                'default': klass.DEFAULT_RC, 
                'help': "Run time configuration. This is loaded after parsing command "
                    "line options, non-default option values wil override persisted "
                    "values (see --update-config) (default: %default). " }),

            (('-K', '--config-key',),{ 'metavar':'ID', 
                'default': klass.DEFAULT_CONFIG_KEY, 
                'help': "Settings root node for run time configuration. "
                    " (default: %default). " }),

            (('-U', '--update-config',),{ 'action':'store_true', 'help': "Write back "
                "configuration after updating the settings with non-default option "
                "values.  This will lose any formatting and comments in the "
                "serialized configuration. ",
                'default': False }),

            (('-C', '--command'),{ 'metavar':'ID', 
                'help': "Action (default: %default). ", 
                'default': klass.DEFAULT_ACTION }),
    
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
                'callback': optparse_decrement_message}),
    
            (('-Q', '--quiet',),{ 'help': "Turn off informal message (level<4) "
                "and prompts (--interactive). ", 
                'dest': 'quiet', 
                'default': False,
                'action': 'callback',
                'callback': optparse_override_quiet }),

            (('--interactive',),{ 'help': "Prompt user if needed, this is"
                    " the default. ", 
                'default': True,
                'action': 'store_true' }),

            (('--non-interactive',),{ 
                'help': "Never prompt, solve or raise error. ", 
                'dest': 'interactive', 
                'default': True,
                'action': 'store_false' }),

            (('--init-config',),{ 'action': 'callback', 'help': "(Re)initialize "
                "runtime-configuration with default values. ",
                'dest': 'command', 
                'callback': optparse_override_handler }),

            (('--print-config',),{ 'action':'callback', 'help': "",
                'dest': 'command', 
                'callback': optparse_override_handler }),

        )

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

    settings = confparse.Values()
    "Complete Values tree with settings. "

    rc = None
    "Values subtree for current program. "

    def __init__(self, settings=None, **kwds):
        if settings:
            self.settings = settings
        "Global settings, set to Values loaded from config_file. "
        self.rc = None
        "Runtime settings for this script. "

        assert not kwds
        #for k in kwds:
        #    if hasattr(self, k):
        #        setattr(self, k, kwds[k])
        #    else:
        #        assert False, k

    def parse_argv(self, options, argv, usage, version):
        # TODO: rewrite to cllct.osutil once that is packaged
        #parser, opts, paths = parse_argv_split(
        #        self.OPTIONS, argv, self.USAGE, self.VERSION)

        parser = optparse.OptionParser(usage, version=version)

        optnames = []
        nullable = []
        for opt in options:
            parser.add_option(*opt[0], **opt[1])

        optsv, args = parser.parse_args(argv)

        return parser, optsv, args

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

    main_handlers = [
#            'main_config',
            'main_run_actions'
        ]

    # XXX: refactor to use name indexed handler registry
    command_registry = {}

    def main(self, argv=None):
        opts, args = self.main_default(argv)
        for hname in self.main_handlers:
            hfunc = getattr(self, hname)
            hfunc(opts, args)

    def main_default(self, argv=None):
        """
        Prepare `self.settings` by loading nearest configuration file,
        then parse ARGV
        """
        config_file = self.get_config_file()
        self.settings.config_file = config_file
        self.settings = confparse.load_path(self.settings.config_file)
        "Static, persisted self.settings. "
        #    self.init_config() # case 1: 
        #        # file does not exist at all, init is automatic
        assert self.settings.config_file, \
            "No existing configuration found, please rerun/repair installation. "
 
        #self.main_user_defaults()

        # parse arguments
        if not argv:
            argv = sys.argv[1:]
        parser, opts, args = self.parse_argv(
                self.get_options(), argv, self.USAGE, self.VERSION)

        # Get a reference to the RC; searches config_file for specific section
        config_key = self.DEFAULT_CONFIG_KEY
        if hasattr(opts, 'config_key') and opts.config_key:
            config_key = opts.config_key

        if not hasattr(self.settings, config_key):
            if opts.command == 'init_config':
                self.init_config_submod()
            else:
                err("Config key must exist in %s ('%s'), use --init-config. " % (
                    opts.config_file, opts.config_key))
                sys.exit(1)

        self.rc = getattr(self.settings, config_key)

        #self.main_option_overrides(parser, opts)

        self.parser = parser

        return opts, args

    def main_prepare_kwds(self, handler, opts, args):
        #print handler, opts, args, inspect.getargspec(handler)
        func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
                inspect.getargspec(handler)
            
        assert func_arg_vars.pop(0) == 'self'
        ret_args, ret_kwds = (), {}

        if func_kwds_var:
            ret_kwds = {'options':None,'args':None}

        if func_defaults:
            func_defaults = list(func_defaults) 

        while func_defaults:
            arg_name = func_arg_vars.pop()
            value = func_defaults.pop()
            if hasattr(self.settings, arg_name):
                value = getattr(self.settings, arg_name)
            ret_kwds[arg_name] = value
        
        if func_args_var:
            assert len(args) >= len(func_arg_vars), (args, func_arg_vars, handler)
        else:
            assert len(args) == len(func_arg_vars), (args, func_arg_vars, handler)
        args += tuple(args)

        if "options" in ret_kwds:
            ret_kwds['options'] = opts
        if "arguments" in ret_kwds:
            ret_kwds['arguments'] = args

# FIXME: merge opts with rc before running command, (see init/update-config)
        return ret_args, ret_kwds

    def main_run_actions(self, opts, args):
        actions = [opts.command]
        while actions:
            actionId = actions.pop(0)
            action = getattr(self, actionId)
            assert callable(action), (action, actionId)
            err("Notice: running %s", actionId)
            arg_list, kwd_dict = self.main_prepare_kwds(action, opts, args)
            ret = action(*arg_list, **kwd_dict)
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
        # TODO: setup.py script

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
            setattr(settings, config_key, confparse.Values())
            rc = getattr(settings, config_key)
            print settings
        assert config_key
        assert isinstance(rc, confparse.Values)
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
        self.rc.version = self.VERSION;

    def update_config(self):
        #if not self.rc.root == self.settings:
        #	self.settings.
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
        print '# self.settings.config_file =', self.settings.config_file
        if self.rc:
            confparse.yaml_dump(self.rc.copy(), sys.stdout)
        return False

    def get_config(self, name):
        rcfile = list(confparse.expand_config_path(name))
        print name, rcfile

    def stat(self, options=None, arguments=None):
        if not self.rc:
            err("Missing run-com for %s", self.NAME)
        elif not self.rc.version:
            err("Missing version for run-com")
        elif self.VERSION != self.rc.version:
            if self.VERSION > self.rc.version:
                err("Run com requires upgrade")
            else:
                err("Run com version mismatch: %s vs %s", self.rc.version,
                        self.VERSION)
        print arguments, options

    def help(self, parser, opts, args):
        print """
        libcmd.Cmd.help
        """


if __name__ == '__main__':
    Cmd().main()


