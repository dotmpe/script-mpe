import optparse
import os
import sys

import confparse
import lib
from libcmd import err
from target import Target


def optparse_decrement_message(option, optstr, value, parser):
    "Lower output-message threshold. "
    parser.values.quiet = False
    parser.values.messages -= 1

def optparse_override_quiet(option, optstr, value, parser):
    "Turn off non-essential output. "
    parser.values.quiet = True
    parser.values.interactive = False
    parser.values.messages = 4 # skip warning and below


class Command(object):

    # XXX: to replace libcmd.Cmd
    namespace = 'cmd', 'http://project.dotmpe.com/script/#/cmdline.Command'

    handlers = [
            'cmd:options',
        ]
    depends = {
            #'cmd:static': [],
            'cmd:prog': [],
            'cmd:config': ['cmd:prog'],
            'cmd:options': ['cmd:config',]
        }

    default_rc = 'cllct.rc'
        
    @classmethod
    def get_opts(clss):
        """
        Return tuples with command-line option specs.
        """
        return (
            (('-c', '--config',),{ 'metavar':'NAME', 
                'dest': "config_file",
                'default': clss.default_rc, 
                'help': "Run time configuration. This is loaded after parsing command "
                    "line options, non-default option values wil override persisted "
                    "values (see --update-config) (default: %default). " }),

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
        )

    def get_options(self):
        opts = []
        for klass in self.__class__.mro():
            if hasattr(klass, 'get_opts'):
                opts += list(klass.get_opts())
        return opts

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
        for opt in options:
            parser.add_option(*opt[0], **opt[1])

        optsv, args = parser.parse_args(argv)

        optsd = {}
        for name in dir(optsv):
            v = getattr(optsv, name)
            if not name.startswith('_') and not callable(v):
                optsd[name] = v

        return parser, optsv, optsd, args

    def find_config_file(self):
        rcfile = list(confparse.expand_config_path(self.default_rc))
        if rcfile:
            config_file = rcfile.pop()
        else:
            config_file = self.default_rc
        "Configuration filename."

        if not os.path.exists(config_file):
            assert False, "Missing %s, perhaps use init_config_file"%config_file
        
        return config_file


    ## Handlers

    def cmd_prog(self):
        """
        Command-line program static properties.
        """
        prog = confparse.Values(dict(
            argv=sys.argv[1:],
            usage="Usage % [options|targets]",
            name=os.path.splitext(os.path.basename(__file__))[0],
            version="0.1",
            pwd=os.getcwd(),
        ))
        yield dict(prog=prog)

    def cmd_config(self):
        """
        Init settings object from persisted config.
        """
        config_file = self.find_config_file()
        yield dict(config_file=config_file)
        yield dict(settings=confparse.load_path(config_file))

    def cmd_options(self, settings=None, prog=None):
        """
        Parse arguments
        """
        parser, opts, kwds_, args = self.parse_argv(
                self.get_options(), prog['argv'], prog['usage'], prog['version'])
        yield kwds_
        yield dict(opts=opts)
        yield args

lib.namespaces.update((Command.namespace,))
Target.register(Command)
