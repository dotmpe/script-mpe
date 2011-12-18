#!/usr/bin/env python
"""
"""
import optparse
import os
import sys
from os.path import join, isdir

import confparse


settings = confparse.load('cllct.rc')
"Parse settings. "


def err(msg, *args):
    "Print error or other syslog notice. "
    print >> sys.stderr, msg % args

class Cmd(object):

    # Class variables

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    VERSION = "0.1"

    USAGE = """Usage: %prog [options] paths """

    DEFAULT_RC = 'cllct.rc'
    DEFAULT_CONFIG_KEY = NAME

    def get_opts(self):
        return (
            (('-c', '--config'),{ 'metavar':'NAME', 'default': self.DEFAULT_RC, 
                'dest': "config_file",
                'help': "Run time configuration. This is loaded after parsing command "
                "line options, non-default option values wil override persisted "
                "values (see --update-config) (default: %default). " }),

            (('-K', '--config-key'),{ 'metavar':'ID', 'default': self.DEFAULT_CONFIG_KEY, 
                'dest': "config_key",
                'help': "Settings root node for run time configuration. "
                " (default: %default). " }),

            (('-C', '--update-config'),{ 'action':'store_true', 'help': "Write back "
                "configuration after updating the settings with non-default option "
                "values.  This will lose any formatting and comments in the "
                "serialized configuration. " }),

            (('--init-config',),{ 'action':'store_true', 'help': "(Re)initialize "
                "runtime-configuration with default values. " }),

            (('--print-config',),{ 'action':'store_true', 'help': "" }),

#    (('-v', ''),{'dest':'verboseness','default': 0, 'action':'count',
#        'help': "Increase chattyness (defaults to 0 or the CLLCT_DEBUG env.  var.)"}),
        )

    "Options are divided into a couple of classes, unclassified keys are treated "
    "as rc settings. "
    NONTRANSIENT_OPTS = ['init_config', 'print_config', 'update_config']
    ""
    TRANSIENT_OPTS = []
    ""
    DEFAULT_ACTION = ''

    settings = confparse.Values()
    "Complete Values tree with settings. "

    rc = None
    "Values subtree for current program. "

    def __init__(self, **kwds):
        global settings

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

    def stat(self, parser, *args, **opts):
        print parser, opts, args

    # TODO: rewrite to cllct.osutil once that is packaged
    def parse_argv(self, options, argv, usage, version):
        #parser, opts, paths = parse_argv_split(
        #        self.OPTIONS, argv, self.USAGE, self.VERSION)

        parser = optparse.OptionParser(usage, version=version)

        optnames = []
        nullable = []
        for opt in options:
            parser.add_option(*opt[0], **opt[1])
            if 'dest' in opt[1]:
                optnames.append(opt[1]['dest'])
            else:
                optnames.append(opt[0][-1].lstrip('-').replace('-','_'))
            if 'default' not in opt[1]:
                nullable.append(optnames[-1])

        optsv, args = parser.parse_args(argv)
        opts = {}

        # FIXME: instead of degrade by converting to dict, add optname/nullable name
        # lists to options Values instance
        for name in optnames:
            if not hasattr(optsv, name) and name in nullable:
                continue
            opts[name] = getattr(optsv, name)
        return parser, opts, args

    def rc_cli_override(self, parser, opts):
        """
        Update settings from values from parsed options. Use --update-config to 
        write them to disk.
        """
        for o in opts:
            if o in self.NONTRANSIENT_OPTS: # opt-key does not indicate setting
                continue
            elif hasattr(self.settings, o):
                setattr(self.settings, o, opts[o])
            elif hasattr(self.rc, o):
                setattr(self.rc, o, opts[o])
            else:
                err("Ignored option override for %s: %s", self.settings.config_file, o)

    def main(self, argv=None):
        rcfile = list(confparse.expand_config_path(self.DEFAULT_RC))
        if rcfile:
            config_file = rcfile.pop()
        else:
            config_file = self.DEFAULT_RC
        "Configuration filename."

        self.settings.config_file = config_file
        if not os.path.exists(config_file):
            self.init_config() # case 1: 
                # file does not exist at all, init is automatic
        assert self.settings.config_file, \
            "No existing configuration found, please rerun/repair installation. "

        self.settings = confparse.load_path(self.settings.config_file)
        "Static, persisted self.settings. "
        # settings are already loaded, file initialized if needed
        # XXX: cannot overwrite file location
        self.settings.config_file = config_file
  
        # parse arguments
        if not argv:
            argv = sys.argv[1:]
        parser, opts, args = self.parse_argv(self.get_opts(), argv, self.USAGE,
                self.VERSION)

        self.cli_main(parser, opts, args)

    def cli_main(self, parser, opts, args):
        """
        if args:
            cmd = args.pop(0)
        else:
            cmd = self.DEFAULT_CMD
        assert hasattr(self, cmd), cmd
        cmd_ = getattr(self, cmd)
        assert callable(cmd_), cmd_
        cmd_(parser, *args, **opts)
        """

        # Get a reference to the RC; searches config_file for specific section
        if 'config_key' in opts and opts['config_key']:
            if not hasattr(self.settings, opts['config_key']):
                print 'missing', self.settings, opts['config_key']
                if 'init_config' in opts and opts['init_config']:
                    self.init_config() # Case 2: must be explicit
                else:
                    err("Config key must exist in %s ('%s'), use --init-config. " % (
                        opts['config_file'], opts['config_key']))
                    sys.exit(1)
            self.rc = getattr(self.settings, opts['config_key'])
        elif 'config_key' not in opts:
            self.rc = getattr(self.settings, self.DEFAULT_CONFIG_KEY)
        else:
            self.rc = self.settings

        self.rc_cli_override(parser, opts)
        actions = []
        for o in self.NONTRANSIENT_OPTS + self.TRANSIENT_OPTS:
            if o in opts and opts[o]:
                actions += [o]

        if not actions and self.DEFAULT_ACTION:
            actions = [self.DEFAULT_ACTION]

        for o in actions:
            ret = getattr(self, o)(*args, **opts)
            if ret != None and not ret:
                return
            if isinstance(ret, int):
                sys.exit(ret)

    def init_config(self):
        config_key = self.NAME
        # TODO: setup.py script

        # Create if needed and load config file
        if self.settings.config_file:
            config_file = self.settings.config_file
        else:
            config_file = os.path.join(os.path.expanduser('~'), '.'+self.DEFAULT_RC)

        if not os.path.exists(config_file):
            os.mknod(config_file)
        settings = confparse.load_path(config_file)
        settings.set_source_key('config_file')
        settings.config_file = config_file

        # Reset sub-Values of settings, or use settings itself
        if config_key:
            setattr(settings, config_key, confparse.Values())
            rc = getattr(settings, config_key)
        else:
            rc = settings

        self.settings = settings
        self.rc = rc

        self.init_config_defaults()

        v = raw_input("Write new config to %s? [Yn]" % settings.config_file)
        if not v.strip() or v.lower().strip() == 'y':
            settings.commit()
            print "File rewritten. "
        else:
            print "Not writing file. "

    def update_config(self):
        self.rc.commit()

    def print_config(self):
        if self.rc:
            confparse.yaml_dump(self.rc.copy(), sys.stdout)
        else:
            err("Config section is empty");
        return False

    def help(self, parser, opts, args):
        print """
        libcmd.Cmd.help
        """


if __name__ == '__main__':
    Cmd().main()


