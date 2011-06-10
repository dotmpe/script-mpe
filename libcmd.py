#!/usr/bin/python
"""
"""
import optparse
import os, re, sys
from os.path import join, isdir

import confparse


config = list(confparse.expand_config_path('cllct.rc'))
"Find configuration file. "

settings = confparse.load_path(*config)
"Parse settings. "


class Cmd:

    # Class variables

    USAGE = """Usage: %prog [options] paths """

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    VERSION = "0.1"
    USAGE = """Usage: %prog [options] paths """
    DEFAULT_RC = 'cllct.rc'
    DEFAULT_CONFIG_KEY = NAME
    DEFAULT_CMD = 'stat'
    OPTIONS = (

    )

    settings = confparse.Values()
    "Complete Values tree with settings. "
    rc = None
    "Values subtree for current program. "

    def __init__(self):
        global settings
        self.settings = settings

    def stat(self, parser, opts, args):
        print parser, opts, args

    # TODO: rewrite to cllct.osutil once that is packaged
    def parse_argv(self, argv):
        if not argv:
            argv = sys.argv[1:]
        #parser, opts, paths = parse_argv_split(
        #        self.OPTIONS, argv, self.USAGE, self.VERSION)

        parser = optparse.OptionParser(self.USAGE, version=self.VERSION)
        optnames = []
        nullable = []
        for opt in self.OPTIONS:
            #parser.add_option(*_optprefix(opt[0]), **opt[1])
            parser.add_option(*opt[0], **opt[1])
            if 'dest' in opt[1]:
                optnames.append(opt[1]['dest'])
            else:
                optnames.append(opt[0][-1].lstrip('-').replace('-','_'))
            if 'default' not in opt[1]:
                nullable.append(optnames[-1])

        optsv, args = parser.parse_args(argv)
        opts = {}
        for name in optnames:
            if not hasattr(optsv, name) and name in nullable:
                continue
            opts[name] = getattr(optsv, name)
        return parser, opts, args

    def main(self, argv=None):
        rcfile = list(confparse.expand_config_path(self.DEFAULT_RC))
        if rcfile:
            self.settings.config_file = rcfile.pop()
        else:
            self.settings.config_file = self.DEFAULT_RC
        "Configuration filename. "

        if not self.settings.config_file or not os.path.exists(self.settings.config_file):
            self.rc_init_default()
        assert self.settings.config_file, \
            "No existing configuration found, please rerun/repair installation. "

        self.settings = confparse.load_path(self.settings.config_file)
        "Static, persisted self.settings. "
  
        parser, opts, args = self.parse_argv(argv)

        if args:
            cmd = args.pop(0)
        else:
            cmd = self.DEFAULT_CMD
        assert hasattr(self, cmd), cmd
        cmd_ = getattr(self, cmd)
        assert callable(cmd_), cmd_
        cmd_(parser, opts, args)
        

if __name__ == '__main__':
    Cmd().main()


