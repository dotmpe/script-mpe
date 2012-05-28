#!/usr/bin/env python
"""
"""
import os, sys, re, anydbm

import txs

from cmdline import Command
import lib
import log
from target import Target, AbstractTargetResolver


class Lind(Command, AbstractTargetResolver):

    namespace = 'lnd', 'http://project.dotmpe.com/script/#/cmdline.Lind'

    handlers = [
            'lnd:tag'
        ]
    depends = {
            'lnd:tag': ['txs:pwd'],
        }

    @classmethod
    def get_opts(clss):
        """
        Return tuples with command-line option specs.
        """
        return ()

    def lnd_tag(self, opts=None, sa=None, ur=None, pwd=None):
        """
        Experiment, interactive interface.
        Tagging.
        """
        log.debug("{bblack}lnd{bwhite}:tag{default}")

        if not pwd:
            log.err("Not initialized")
            yield 1

        tags = {}
        if '' not in tags:
            tags[''] = 'Root'
        FS_Path_split = re.compile('[\/\.\+,]+').split

        log.info("{bblack}Tagging paths in {green}%s{default}",
                os.path.realpath('.') + os.sep)

        try:
            for root, dirs, files in os.walk(pwd.location.path):
                for name in files + dirs:
                    log.info("{bblack}Typing tags for {green}%s{default}",
                            name)
                    path = FS_Path_split(os.path.join( root, name ))
                    for tag in path:
                        # Ask about each new tag, TODO: or rename, fuzzy match.      
                        if tag not in tags:
                            type = raw_input('%s%s%s:?' % (
                                log.palette['yellow'], tag,
                                log.palette['default']) )
                            if not type: type = 'Tag'
                            tags[tag] = type

                    log.info(''.join( [ "{bwhite} %s:{green}%s{default}" % (tag, name)
                        for tag in path if tag in tags] ))

        except KeyboardInterrupt, e:
            print e
            pass


lib.namespaces.update((Lind.namespace,))
Target.register(Lind)


if __name__ == '__main__':
    Lind().main()

