#!/usr/bin/env python
"""
"""
import os, sys, re, anydbm

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from cmdline import Command
import lib
import libcmd
import log
from target import Target, AbstractTargetResolver
# XXX
from taxus import SqlBase, SessionMixin


# to replace taxus.py
class Txs(Command, AbstractTargetResolver, SessionMixin):

    namespace = 'txs', 'http://project.dotmpe.com/script/#/cmdline.Taxus'

    handlers = [
            'txs:session',
            'txs:tag',
        ]
    depends = {
            'txs:session': ['cmd:options'],
            'txs:tag': ['txs:session'],
        }

    DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    @classmethod
    def get_opts(clss):
        return (

    #            (('-g', '--global-objects'), { 'metavar':'URI', 
    #                'default': clss.DEFAULT_OBJECT_DB, 
    #                'dest': 'objectdbref',
    #                }),

                (('-d', '--dbref'), { 'metavar':'URI', 
                    'default': clss.DEFAULT_DB, 
                    'dest': 'dbref',
                    'help': "A URI formatted relational DB access description "
                        "(SQLAlchemy implementation). Ex: "
                        " `sqlite:///taxus.sqlite`,"
                        " `mysql://taxus-user@localhost/taxus`. "
                        "The default value (%default) may be overwritten by configuration "
                        "and/or command line option. " }),

                (('-q', '--query'), {'action':'callback', 
                    'callback_args': ('query',),
                    'callback': libcmd.optparse_override_handler,
                    'dest': 'command',
                    'help': "TODO" }),
#'-X', 
                (('--init-database',), {
                    'action': 'callback', 
                    'callback_args': ('init_database',),
                    'dest': 'command', 
                    'callback': libcmd.optparse_override_handler,
                    'help': "TODO" }),

                (('--init-host',), {
                    'action': 'callback', 
                    'callback_args': ('init_host',),
                    'dest': 'command', 
                    'callback': libcmd.optparse_override_handler,
                    'help': "TODO" }),
            )

    # TODO; test and remove from taxus.py
    def txs_session(self, prog=None, sa=None, opts=None, settings=None):
        dbref = opts.dbref
        log.debug("Initializing SQLAlchemy session for %s", dbref)
        engine = create_engine(dbref, encoding='utf8')
        if opts.command == 'init_database':
            log.info("Applying SQL DDL to DB %s ", dbref)
            SqlBase.metadata.create_all(engine)
        session = sessionmaker(bind=engine)()
        yield dict(sa=session)

    def txs_tag(self, sa=None, opts=None, settings=None):
        classes = {}
        tags = {}
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

          

lib.namespaces.update((Txs.namespace,))
Target.register(Txs)


if __name__ == '__main__':
    Txs().main()
