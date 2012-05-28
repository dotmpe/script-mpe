#!/usr/bin/env python
"""
"""
import os, sys, re, anydbm
from datetime import datetime


from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm.exc import NoResultFound

from cmdline import Command
import lib
import libcmd
import log
from target import Target, AbstractTargetResolver, keywords, targets
# XXX
from taxus import SqlBase, SessionMixin, current_hostname, \
        Node, INode, CachedContent, \
        ID, Name, Locator, \
        Host, \
        Locator, Tag, ChecksumDigest, SHA1Digest
import taxus_out



class URLResolver(object):

    def __init__(self, host, sasession):
        self.host = host
        self.sa = sasession

    def getPWD(self, opts):
        """
        Return INode object for current directory.
        """
        cwd = os.path.abspath(os.getcwd())
        ref = "file:%s%s" % (self.host.netpath, cwd)
        try:
            return self.sa.query(INode)\
                    .join('location')\
                    .filter(Locator.ref == ref)\
                    .one()
        except NoResultFound, e:
            pass
        if not opts.init:
            log.warn("Not a known dir %s", cwd)
            return
        locator = Locator(
                ref=ref,
                date_added=datetime.now())
        #locator.host
        #        host=self.host,
        locator.commit()
        inode = INode(
                #inode_number=,
                #itype=,
                location=locator,
                date_added=datetime.now())
        inode.commit()
        return inode

# to replace taxus.py
class Txs(Command, AbstractTargetResolver, SessionMixin):

    namespace = 'txs', 'http://project.dotmpe.com/script/#/cmdline.Taxus'

    handlers = [
#            'txs:session',
            'txs:pwd',
#            'txs:status',
#            'txs:run',
        ]
    depends = {
            'txs:session': ['cmd:options'],
            'txs:pwd': ['txs:session'],
            'txs:ls': ['txs:pwd'],
#            'txs:status': ['txs:session'],
#            'txs:run': ['txs:session'],
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
                (('--init',), {
                    'action': 'store_true',
                    'help': "Initialize target" }),

#                (('--init-database',), {
#                    'action': 'callback', 
#                    'callback_args': ('init_database',),
#                    'dest': 'command', 
#                    'callback': libcmd.optparse_override_handler,
#                    'help': "TODO" }),
#
#                (('--init-host',), {
#                    'action': 'callback', 
#                    'callback_args': ('init_host',),
#                    'dest': 'command', 
#                    'callback': libcmd.optparse_override_handler,
#                    'help': "TODO" }),
            )

    def hostname_find(self, args, sa=None):
        if not args:
            hostnamestr = current_hostname()
        else:
            hostnamestr = args.pop(0)
        if not hostnamestr:
            return
        if not sa:
            log.crit("No session, cannot retrieve anything!")
            return
        try:
            name = sa\
                    .query(Name)\
                    .filter(Name.name == hostnamestr).one()
        except NoResultFound, e:
            name = None
        return name

    def host_find(self, args, sa=None):
        """
        Identify given or current host.
        """
        name = None
        if args:
            args = list(args)
            name = args.pop(0)
        if isinstance(name, Name):
            name = name.name

        try:
            host, name_ = sa.query(Host, Name)\
                .join('hostname')\
                .filter(Name.name == name).one()
            return host
        except NoResultFound, e:
            return

        if not isinstance(name, Name):
            name = self.hostname_find([name], sa)
        if not name:
            return
        node = Node
        try:
            node = sa.query(Host)\
                    .filter(Host.hostname == name).one()
        except NoResultFound, e:
            return
        return node


    # TODO; test and remove from taxus.py
    def txs_session(self, prog=None, sa=None, opts=None, settings=None):
        # SA session
        dbref = opts.dbref
        if opts.init:
            log.debug("Initializing SQLAlchemy session for %s", dbref)
        #engine = create_engine(dbref, encoding='utf8')
        #if opts.init:
            #log.info("Applying SQL DDL to DB %s ", dbref)
        sa = SessionMixin.get_instance('default', opts.dbref, opts.init)
            #SqlBase.metadata.create_all(engine)
        #sa = sessionmaker(bind=engine)()
        # Host
        hostnamestr = current_hostname(opts.init, opts.interactive)
        if opts.init:
            hostname = self.hostname_find([hostnamestr], sa)
            assert not hostname or not isinstance(hostname, (tuple, list)), hostname
            if not hostname:
                log.note("New Name: %s", hostnamestr)
                hostname = Name(
                        name=hostnamestr,
                        date_added=datetime.now())
                hostname.commit()
            else:
                log.warn("Name exists: %s", hostname)
            assert hostname
            host = self.host_find([hostname], sa)
            if not host:
                log.note("New Host: %s", hostnamestr)
                host = Host(
                        hostname=hostname,
                        date_added=datetime.now())
                host.commit()
            else:
                log.warn("Host exists: %s", host)
            assert host
        else:
            host, name = sa.query(Host, Name)\
                .join('hostname')\
                .filter(Name.name == hostnamestr).one()
            if not host:
                log.crit("Could not get host")
        urlresolver = URLResolver(host, sa)
        yield keywords(sa=sa, ur=urlresolver)

    def txs_pwd(self, prog=None, sa=None, ur=None, opts=None, settings=None):
        log.debug("{bblack}txs{bwhite}:pwd{default}")
        pwd = ur.getPWD(opts)
        if opts.init:
            log.note("New INode %s", pwd)
        yield keywords(pwd=pwd)

    def txs_ls(self, prog=None, sa=None, ur=None, opts=None, settings=None):
        log.debug("{bblack}txs{bwhite}:ls{default}")
        print ur.getPWD(opts)

    def txs_run(self, sa=None, opts=None, settings=None):
        log.debug("{bblack}txs{bwhite}:run{default}")
        # XXX: Interactive part, see lind.
        """
        """
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
