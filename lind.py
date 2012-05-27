#!/usr/bin/env python
"""
"""
import os, sys, re, anydbm

from cmdline import Command
import lib
import log
from target import Target, AbstractTargetResolver


class Lind(Command, AbstractTargetResolver):

    namespace = 'lnd', 'http://project.dotmpe.com/script/#/cmdline.Lind'

    handlers = [
            #xxx
            'cmd:prog', # need one in this list
            'cmd:config', # need one in this list
            'cmd:options' # need one in this list
        ]
    depends = {
            'lnd:tag': ['cmd:options'],
        }

    def lnd_tag(self, prog=None, opts=None, settings=None):
        """
        Experiment, interactive interface.
        Tagging.
        """
        log.debug("{bblack}lnd{bwhite}:tag{default}")
        log.debug("{yellow}%r", prog)
        log.debug("%r{green}", opts)
        log.debug("%r{default}", settings)
#
        db_file = os.path.expanduser('~/x-namespace,tags,scripts.db') 
        if os.path.exists(db_file):
            DB_MODE = 'rw'
        else:
            DB_MODE = 'n'
        log.debug("Opening %s", db_file)
        tags = anydbm.open(db_file, DB_MODE)
        log.info("AnyDB: %s, %s", db_file, DB_MODE)

        classes = {}

        # TODO into db
        if '' not in tags:
            tags[''] = 'Root'
        FS_Path_split = re.compile('[\/\.\+,]+').split

        log.info("{bblack}Tagging paths in {green}%s{default}",
                os.path.realpath('.') + os.sep)

        cwd = os.getcwd()
        try:
            for root, dirs, files in os.walk(cwd):
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
            pass

        tags.close()

lib.namespaces.update((Lind.namespace,))
Target.register(Lind)


if __name__ == '__main__':
    Lind().main()

