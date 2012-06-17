"""
"""
import os, stat, sys
import re, anydbm
from datetime import datetime


from sqlalchemy.orm.exc import NoResultFound

import confparse
import lib
import libcmd
import log
import res
from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
    Target 
# XXX
from taxus import SqlBase, SessionMixin, current_hostname, \
        Node, INode, CachedContent, \
        ID, Name, Locator, \
        Host, \
        Locator, Tag, ChecksumDigest, SHA1Digest
import taxus_out



class LocalPathResolver(object):

    def __init__(self, host, sasession):
        self.host = host
        self.sa = sasession

    def getDir(self, path, opts, exists=True):
        """
        Return INode object for current directory.
        """
        if exists:
            assert os.path.isdir(path), "Missing %s"%path
        node = self.get(path, opts)
        assert node, "Required: %s"%path
        return node

    def get(self, path, opts):
        ref = "file:%s%s" % (self.host.netpath, path)
        try:
            return self.sa.query(INode)\
                    .join('location')\
                    .filter(Node.ntype == INode.Dir)\
                    .filter(Locator.ref == ref)\
                    .one()
        except NoResultFound, e:
            pass
        if not opts.init:
            log.warn("Not a known path %s", path)
            return
        locator = Locator(
                ref=ref,
                date_added=datetime.now())
        #locator.host
        #        host=self.host,
        locator.commit()
        inode = INode(
                ntype=self.get_type(path),
                location=locator,
                date_added=datetime.now())
        inode.commit()
        return inode

    def get_type(self, path):
        mode = os.stat(path).st_mode
        if stat.S_ISLNK(mode):#os.path.islink(path)
            return INode.Symlink
        elif stat.S_ISFIFO(mode):
            return INode.FIFO
        elif stat.S_ISBLK(mode):
            return INode.Device
        elif stat.S_ISSOCK(mode):
            return INode.Socket
        elif os.path.ismount(path):
            return INode.Mount
        elif stat.S_ISDIR(mode):#os.path.isdir(path):
            return INode.Dir
        elif stat.S_ISREG(mode):#os.path.isfile(path):
            return INode.File


DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
DEFAULT_DB = "sqlite:///%s" % DB_PATH
#DEFAULT_OBJECT_DB = os.path.expanduser('~/.cllct/objects.db')

NS = Namespace.register(
        prefix='txs',
        uriref='http://project.dotmpe.com/script/#/cmdline.Taxus'
    )

Options.register(NS, 

#            (('-g', '--global-objects'), { 'metavar':'URI', 
#                'default': DEFAULT_OBJECT_DB, 
#                'dest': 'objectdbref',
#                }),

            (('-d', '--dbref'), { 'metavar':'URI', 
                'default': DEFAULT_DB, 
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

def hostname_find(args, sa=None):
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

def host_find(args, sa=None):
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
        name = hostname_find([name], sa)
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

@Target.register(NS, 'session', 'cmd:options')
def txs_session(prog=None, sa=None, opts=None, settings=None):
    # SA session
    dbref = opts.dbref
    if opts.init:
        log.debug("Initializing SQLAlchemy session for %s", dbref)
    sa = SessionMixin.get_instance('default', opts.dbref, opts.init)
    # Host
    hostnamestr = current_hostname(opts.init, opts.interactive)
    if opts.init:
        hostname = hostname_find([hostnamestr], sa)
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
        host = host_find([hostname], sa)
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
    urlresolver = LocalPathResolver(host, sa)
    yield Keywords(sa=sa, ur=urlresolver)


@Target.register(NS, 'pwd', 'txs:session')
def txs_pwd(prog=None, sa=None, ur=None, opts=None, settings=None):
    log.debug("{bblack}txs{bwhite}:pwd{default}")
    cwd = os.path.abspath(os.getcwd())
    pwd = ur.getDir(cwd, opts)
    yield pwd
    yield Keywords(pwd=pwd)


@Target.register(NS, 'run', 'txs:session')
def txs_run(sa=None, ur=None, opts=None, settings=None):
    log.debug("{bblack}txs{bwhite}:run{default}")
    # XXX: Interactive part, see lind.
    """
    """
    results = []
    if settings.taxus.walk.yield_directly:
        results = None
    classes = {}
    tags = {}
    if '' not in tags:
        tags[''] = 'Root'
    FS_Path_split = re.compile('[\/\.\+,]+').split
    log.info("{bblack}Tagging paths in {green}%s{default}",
            os.path.realpath('.') + os.sep)
    cwd = os.getcwd()
    try:
        for pathstr in res.Dir.walk(cwd, opts):
            path = ur.get(pathstr, opts)
            if isinstance(results, list):
                # XXX: path is not initialized yet
                results.append(pathstr)
            else:
                yield path
            continue
            parts = FS_Path_split(pathstr)
            for tagstr in parts:
                try:
                    tag = sa.query(Tag).filter(Tag.name == tagstr).one()
                    log.note(tag)
                except NoResultFound, e:
                    log.note(e)
                # Ask about each new tag, TODO: or rename, fuzzy match.      
                if tagstr not in tags:
                    type = raw_input('%s%s%s:?' % (
                        log.palette['yellow'], tagstr,
                        log.palette['default']) )
                    if not type: type = 'Tag'
                    tags[tagstr] = type
            log.info(pathstr)
            #log.info(''.join( [ "{bwhite} %s:{green}%s{default}" % (tag, name)
            #    for tag in parts if tag in tags] ))
    except KeyboardInterrupt, e:
        log.note(e)
        pass
    if results:
        for path in results:
            yield path

@Target.register(NS, 'ls', 'txs:pwd')
def txs_ls(pwd=None, ur=None, opts=None):
    log.debug("{bblack}txs{bwhite}:ls{default}")
    node = ur.getDir(pwd, opts)
    print node.location.path
    for rs in res.Dir.walk(node.location.path):
        print rs


