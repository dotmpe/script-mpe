#!/usr/bin/env python
"""
libcmd+taxus (SQLAlchemy) session

FIXME: txs
"""
from __future__ import print_function

import os, stat, sys
from os import sep
import re, anydbm
from datetime import datetime

from sqlalchemy.orm.exc import NoResultFound

from script_mpe.libhtd import *
from script_mpe.libname import Namespace#, Name
from script_mpe.libcmdng import Targets, Arguments, Keywords, Options,\
    Target, TargetResolver
from script_mpe.taxus.v0 import \
        Node, \
        INode, Dir, \
        Name, Tag, \
        Host, Locator



class LocalPathResolver(object):

    def __init__(self, host, sasession):
        self.host = host
        self.sa = sasession

    def getDir(self, path, opts, exists=True):
        """
        Return INode object for current directory.
        """
        assert path, path
        if isinstance(path, INode):
            path = path.local_path
        if exists:
            assert os.path.isdir(path), "Missing %s"%path
        node = self.get(path, opts)
        if not node:
            node = Dir(local_path=path, host=self.host)
        return node

    def get(self, path, opts):
        ref = "file:%s%s" % (self.host.netpath, path)
        try:
            return self.sa.query(INode)\
                    .filter(INode.local_path == path)\
                    .filter(Node.ntype == INode.Dir)\
                    .one()
        except NoResultFound as e:
            pass

        return INode(local_path=path, host=self.host)
        # XXX: why hijack init which is for session init..
        assert False

        if not opts.init:
            log.warn("Not a known path %s", path)
            return
        inode = INode(
                ntype=self.get_type(path),
                local_path=path,
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




def hostname_find(args, sa=None):
    if not args:
        import socket
        hostnamestr = socket.gethostname()
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
    except NoResultFound as e:
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
    except NoResultFound as e:
        return

    if not isinstance(name, Name):
        name = hostname_find([name], sa)
    if not name:
        return
    node = Node
    try:
        node = sa.query(Host)\
                .filter(Host.hostname == name).one()
    except NoResultFound as e:
        return
    return node


NS = Namespace.register(
        prefix='txs',
        uriref='http://project.wtwta.org/script/#/txs'
    )

@Target.register(NS, 'session', 'cmd:options')
def txs_session(prog=None, sa=None, opts=None, settings=None):
    # default SA session
    dbref = opts.dbref
    if opts.init:
        log.debug("Initializing SQLAlchemy session for %s", dbref)
    sa = SessionMixin.get_session('default', opts.dbref, opts.init)
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
    log.info("On %s", host)
    yield Keywords(sa=sa, ur=urlresolver)

@Target.register(NS, 'pwd', 'txs:session')
def txs_pwd(prog=None, sa=None, ur=None, opts=None, settings=None):
    log.debug("{bblack}txs{bwhite}:pwd{default}")
    cwd = os.path.abspath(os.getcwd())
    pwd = ur.getDir(cwd, opts)
    yield pwd
    yield Keywords(pwd=pwd)

@Target.register(NS, 'ls', 'txs:pwd')
def txs_ls(pwd=None, ur=None, opts=None):
    log.debug("{bblack}txs{bwhite}:ls{default}")
    node = ur.getDir(pwd, opts)
    if isinstance(node, basestring):
        print("Dir", node)
    else:
        print('txt: path:', node.local_path)
        for rs in res.Dir.walk_tree_interactive(node.local_path):
            print('txs: walk: rs:', rs)

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
            os.path.realpath('.') + sep)
    cwd = os.getcwd()
    assert isinstance(cwd, basestring), cwd
    try:
        for pathstr in res.Dir.walk_tree_interactive(cwd, opts):
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
                except NoResultFound as e:
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
    except KeyboardInterrupt as e:
        log.note(e)
        pass
    if results:
        for path in results:
            yield path




def oldmain():
    #print TargetResolver().main(['vol:find-volume'])
    TargetResolver().main(['cmd:options'])

if __name__ == '__main__':
    import sys
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)
        sys.exit(0)
    oldmain()
