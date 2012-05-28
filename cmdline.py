#!/usr/bin/env python
"""
"""
import optparse
import os
import re
import sys

import confparse
import lib
import log
from target import Target, keywords, arguments, targets



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


def optparse_decrement_message(option, optstr, value, parser):
    "Lower output-message threshold. "
    parser.values.quiet = False
    parser.values.messages -= 1

def optparse_override_quiet(option, optstr, value, parser):
    "Turn off non-essential output. "
    parser.values.quiet = True
    parser.values.interactive = False
    parser.values.messages = 4 # skip warning and below

def optparse_print_help(options, optstr, value, parser):
    parser.print_help()


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
            'cmd:options': ['cmd:config',],
            'cmd:help': ['cmd:options'],
            'cmd:targets': ['cmd:options']
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

            (('--interactive',),{ 'help': "Force user prompt in certain "
                    "situations. This is the default. ", 
                'default': True,
                'action': 'store_true' }),

            (('--non-interactive',),{ 
                'help': "Never prompt, auto-solve situation by defaults or "
                    "preferences. Otherwise raise error for unclear or risky "
                    "situations. But remember user preferences may override! "
                    "This option should ensure execution completes unattended, "
                    "and as soon soon as possible, but early failure cannot always "
                    "be guaranteed. ", 
                'dest': 'interactive', 
                'default': True,
                'action': 'store_false' }),

        )

    def get_options(self):
        opts = []
        for klass in Target.module_list:
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

        parser = OptionParser(usage, version=version)

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
        log.debug("{bblack}cmd{bwhite}:prog{default}")
        prog = confparse.Values(dict(
            argv=sys.argv[1:],
            usage="Usage % [options|targets]",
            name=os.path.splitext(os.path.basename(__file__))[0],
            version="0.1",
            pwd=os.getcwd(),
        ))
        yield keywords(prog=prog)

    def cmd_config(self, prog=None):
        """
        Init settings object from persisted config.
        """
        log.debug("{bblack}cmd{bwhite}:config{default}")
        assert prog, (self, prog)
        config_file = self.find_config_file()

        prog.update(dict(
            config_file=config_file,
        ))
        yield keywords(
                settings=confparse.load_path(config_file))

    def cmd_options(self, settings=None, prog=None):
        """
        Parse arguments
        """
        log.debug("{bblack}cmd{bwhite}:options{default}")
        parser, opts, kwds_, args_ = self.parse_argv(
                self.get_options(), 
                prog['argv'], 
                prog['usage'], 
                prog['version'])
        prog.update(dict(
            optparser=parser
        ))
        yield keywords(kwds_)
        yield keywords(
            opts=opts,
        )
        args = arguments()
        targs = targets()
        args_ = list(args_)
        while args_:
            a = args_.pop()
            if re.match('[a-z][a-z0-9]+:[a-z0-9-]', a.lower()):
                targs = targets(targs+(a,))
            else:
                args = arguments(args+(a,))
        yield targs
        yield args

    def cmd_targets(self, settings=None, prog=None):
        """
        xxx: deprecate? use --help.
        """
        log.debug("{bblack}cmd{bwhite}:targets{default}")
        optparser.print_targets()
        targets = prog['optparser'].targets
        yield keywords(targets=targets)

    def cmd_help(self, settings=None, prog=None):
        log.debug("{bblack}cmd{bwhite}:help{default}")
        prog['optparser'].print_help()
       

lib.namespaces.update((Command.namespace,))
Target.register(Command)
