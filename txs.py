#!/usr/bin/env python
"""
libcmd+taxus (SQLAlchemy) session

XXX:
    taxus should do basic storage model
    rsr ("resourcer") builds on taxus to explore res.meta further
"""
import os, stat, sys
from os import sep
import re, anydbm
from datetime import datetime

from sqlalchemy.orm.exc import NoResultFound

import confparse
import lib
import libcmd
import log
import res
from libname import Namespace#, Name
from libcmdng import Targets, Arguments, Keywords, Options,\
    Target 
import taxus.checksum
import taxus.core
import taxus.fs
import taxus.generic
import taxus.media
import taxus.model
import taxus.net
import taxus.semweb
import taxus.web
# XXX
import taxus
from taxus import SessionMixin, \
        Node, GroupNode, \
        INode, Dir, \
        Name, Tag, \
        Host, Locator
from taxus.util import current_hostname
#from taxus.iface import gsm, IReferenceResolver



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
        except NoResultFound, e:
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


class TaxusFe(libcmd.StackedCommand):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DEFAULT = [ 'txs_info' ]

    DEPENDS = {
            'txs_session': ['cmd_config'],
            'txs_info': ['txs_session'],
            'txs_show': ['txs_session'],
            'txs_assert': ['txs_session'],
            'txs_assert_group': ['txs_session'],
            'txs_assert_path': ['txs_session'],
            'txs_commit': ['txs_session'],
            'txs_remove': ['txs_session'],
            'txs_list': ['txs_session'],
            'txs_list_groups': ['txs_session'],
        }

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = Klass.get_prefixer(inheritor)
        return (
                # XXX: duplicates Options
                p(('-d', '--dbref'), { 'metavar':'URI', 
                    'default': DEFAULT_DB, 
                    'dest': 'dbref',
                    'help': "A URI formatted relational DB access description "
                        "(SQLAlchemy implementation). Ex: "
                        " `sqlite:///taxus.sqlite`,"
                        " `mysql://taxus-user@localhost/taxus`. "
                        "The default value (%default) may be overwritten by configuration "
                        "and/or command line option. " }),
                p(('--init',), {
                    'action': 'store_true',
                    'help': "Initialize target" }),
                p(('--auto-commit',), {
#                    "default": False,
                    'action': 'store_true',
                    'help': "target" }),
                p(('-q', '--query'), {'action':'callback', 
                    'callback_args': ('query',),
                    'callback': libcmd.optparse_set_handler_list,
                    'dest': 'command',
                    'help': "TODO" }),

                # commands
                p(('--info',), libcmd.cmddict(callback_args=(True,))),
                p(('--assert',), libcmd.cmddict(help="Add Node.")),
                p(('--assert-group',), libcmd.cmddict(help="Add Group-node.")),
                p(('--remove',), libcmd.cmddict(help="Drop Node.")),
                p(('--commit',), libcmd.cmddict(callback_args=(True,))),
                #listtree?
                p(('-l', '--list',), libcmd.cmddict()),
                p(('-t', '--tree',), libcmd.cmddict()),
                p(('--list-groups',), libcmd.cmddict()),
                p(('--show',), libcmd.cmddict(help="Print Node.")),
            )

    def session(self, opts=None):
        dbref = opts.dbref
        if opts.init:
            log.debug("Initializing SQLAlchemy session for %s", dbref)
        sa = SessionMixin.get_session('default', opts.dbref, opts.init)
        yield dict(sa=sa)

    def txs_info(self, opts=None, sa=None):
        log.info("DBRef: %s", opts.dbref)
        log.note("SQLAlchemy session: %s", sa)
        models = taxus.core.ID, Node, Name, Tag, GroupNode, INode, Locator
        cnt = {}
        for m in models:
            cnt[m] = sa.query(m).count()
            log.note("Number of %s: %s", m.__name__, cnt[m])
        if 'node' in self.globaldict and self.globaldict.node:
            log.info("Auto commit: %s", opts.txs_auto_commit) 
            log.info("%s", self.globaldict.node)

    def deref(self, ref, sa):
        assert ref
        m = re.match(r'^([a-zA-Z_][a-zA-Z0-9_-]*):', ref)
        if m:
            nodetype = m.groups()[0]
            return nodetype, ref[ m.end(): ]
        if sep in ref:
            nodetype = 'group'
            if not ref.endswith(sep):
                nodetype = 'node'# XXX not using path elems of node-'path'
            return nodetype, ref
        return 'node', ref

    def txs_assert(self, ref, sa, opts):
        """
        <node>
        <group>/<node> (node+path)
        <group>/<group> (group+path)

        <group root=true>/<group>/<node>
        """
        nodetype, localpart = self.deref( ref, sa )
        #NodeType = getUtility(INameRegistry).lookup(nodetype)
        subh = 'txs_assert_%s' % nodetype
        updatedict = dict( name=localpart, path=None )
        if sep in ref:
            elems = ref.split(sep)
            name = elems.pop()
            updatedict.update(dict( path=sep.join(elems), name=name ))
        self.execute( subh, updatedict )
    
    def _assert_node(self, Klass, name, sa, opts):
        """
        Helper for node creation.
        """
        assert name
        node = Klass.find(( Klass.name==name, ), sa=sa)
        if node:
            if name != node.name:
                node.name = name
        else:
            node = Klass(name=name, date_added=datetime.now())
            sa.add(node)
            if opts.txs_auto_commit:
                sa.commit()
        yield dict( node = node )
        log.note('Asserted %s', node)

    def txs_assert_node( self, path, name ):
        self.execute( '_assert_node', dict( Klass=Node, name=name ) )
        if path:
            self.execute( 'txs_assert_group', dict( path=path ))
            path = sep.join(( path, name ))
            self.execute( 'txs_assert_path', dict( path=path ))

    def txs_assert_group(self, path, sa=None, opts=None):
        """
        Assure Group with `name` exists (or any subtype).
        """
        assert path and isinstance( path, basestring )
        if sep in path:
            elems = path.split(sep)
            while elems:
                elem = elems.pop(0)
                for x in self.txs_assert_group( elem, sa, opts ):
                    yield x
            self.execute( 'txs_assert_path', dict( path=path ) )
        else:
            for x in self._assert_node(GroupNode, path, sa, opts):
                yield x
            
    def txs_assert_path(self, path, sa, opts):
        """
        Put each subnode in a container::

            <group>/<group>/<node>

        """
        assert path
        if sep in path:
            nodes = []
            elems = path.split(sep)
            # resolve elements to nodes
            while elems:
                elem = elems.pop(0)
                node = Node.fetch(( Node.name == elem, ), sa=sa)
                nodes += [ node ]
                # XXX assert GroupNode?
            # assert path
            yield dict(path_nodes = nodes)
            root = nodes.pop(0)
            while nodes:
                node = nodes.pop(0)
                root.subnodes.append( node )
                sa.add(root)
                root = node
        if opts.txs_auto_commit:
            opts.commit()

    def txs_remove(self, ref, sa, opts):
        node = Node.find(( Node.name == ref, ))
        sa.delete( node )
        if opts.txs_auto_commit:
            sa.commit()

    def txs_commit(self, sa):
        sa.commit()

    def set_root_bool(self, sa=None):
        """
        set bool = true
        where 
            count(jt.node_id) == 0
            jt.group_id
        core.groupnode_node_table\
            update().values(
                )
        """

    def txs_show(self, ref_or_node, sa ):
        if isinstance( ref_or_node, basestring ):
            nodetype, localpart = self.deref(ref_or_node, sa)
            node = Node.find(( Node.name == localpart, ))
            print node
        
    def txs_list(self, node, sa=None):
        #if node:
        #    group = GroupNode.find(( Node.name == node, ))
        #    if not group:
        #        log.err("No node for %s", node)
        #    else:
        #        print group
        #        for subnode in group.subnodes:
        #            print '\t', subnode
        #else:
            ns = sa.query(Node).all()
            # XXX idem as erlier, some mappings in adapter
            fields = 'node_id', 'ntype', 'name',
            # XXX should need a table formatter here
            print '#', ', '.join(fields)
            for n in ns:
                for f in fields:
                    v = getattr(n, f)
                    if isinstance( v, unicode ):
                        v = v.encode('utf-8')
                    print v,
                print

    def list_groups(self, sa=None):
        gns = sa.query(GroupNode).all()
        fields = 'node_id', 'name', 'subnodes'
        print '#', ', '.join(fields)
        for n in gns:
            for f in fields:
                print getattr(n, f),
            print

    def tree(self, sa=None):
        trees = sa.query(GroupNode)\
                .filter(( GroupNode.root, )).all()


DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
DEFAULT_DB = "sqlite:///%s" % DB_PATH
#DEFAULT_OBJECT_DB = os.path.expanduser('~/.cllct/objects.db')

NS = Namespace.register(
        prefix='txs',
        uriref='http://project.dotmpe.com/script/#/cmdline.Taxus'
    )

Options.register(NS, 
        
        *TaxusFe.get_optspec(None)

#            (('-g', '--global-objects'), { 'metavar':'URI', 
#                'default': DEFAULT_OBJECT_DB, 
#                'dest': 'objectdbref',
#                }),

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
        print "Dir", node
    else:
        print node.local_path
        for rs in res.Dir.walk_tree_interactive(node.local_path):
            print rs

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


if __name__ == '__main__':
    TaxusFe.main()

