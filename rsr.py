#!/usr/bin/env python
"""
Filesystem metadata & management routines.

See Resourcer.rst
"""
from datetime import datetime
from glob import glob
import os
from os.path import sep
import re
import shelve
from pprint import pformat
import lib
import log
import confparse
import res
from res.session import Session
import taxus
from taxus import SessionMixin, Node, Name, Tag

import os
import libcmd



#@Target.register(NS, 'status', 'rsr:volume')
def rsr_status(prog=None, volume=None, opts=None):
    log.debug("{bblack}rsr{bwhite}:status{default}")
    # print if superdir is OK
    #Meta.index.get(dirname(prog.pwd))
    # start lookign from current dir
    meta = res.Meta(volume)
    opts = confparse.Values(res.Dir.walk_opts.copy())
    opts.interactive = False
    opts.recurse = True
    opts.max_depth = 1
    for path in res.Dir.walk_tree_interactive(prog.pwd, opts=opts):
        if not meta.exists(path):
            yield { 'status': { 'unknown': [ path ] } }
            continue
        elif not meta.clean(path):
            yield { 'status': { 'updated': [ path ] } }
    yield 0


#@Target.register(NS, 'add', 'rsr:volume')
def rsr_add(prog=None, opts=None, volume=None, args=None):
    """
    Add files. Put records into stage-shelve.
    """
    meta = res.Meta(volume)
    for name in args:
        yield meta.add(name, prog, opts)
    # print contents and status of stage
    yield StageReport(meta)
    # print unknown stuff
    #yield VolumeReport()


#@Target.register(NS, 'update-volume', 'rsr:volume')
def rsr_update_volume(prog=None, volume=None, opts=None, *args):
    """
    Walk all files, determine identity. Keep one ID registry per host.

See update_metafiles
    Walk all files, gather metadata into metafile.

    Create metafile if needed. Fill in
        - X-First-Seen
    This and every following update also write:
        - X-Last-Update
        - X-Meta-Checksum
    Metafile is reloaded when
        - Metafile modification exceeds X-Last-Update
    Updates of all fields are done when:
        - File modification exceeds X-Last-Modified
        - File size does not match Length
        - If any of above mentioned and at least one Digest field is not present.

    """
    for path in res.Dir.walk(prog.pwd):
        if not os.path.isfile(path):
            continue
        mf = res.Metafile(path)
        mf.tmp_convert()


#@Target.register(NS, 'update-metafiles', 'rsr:volume')
def rsr_update_metafiles(prog=None, volume=None, volumedb=None, opts=None):
    log.debug("{bblack}rsr{bwhite}:update-volume{default}")
    i = 0
    for path in res.Metafile.walk(prog.pwd):
        print path
        i += 1
        new, updated = False, False
        metafile = res.Metafile(path)
        #if options:
        #metafile.basedir = 'media/application/metalink/'
        #if metafile.key in volumedb:
        #    metafile = volumedb[metafile.key]
        #    #log.info("Found %s in volumedb", metafile.key)
        #else:
        #    new = True
        if metafile.needs_update():
            log.note("Updating metafile for %s", metafile.path)
            metafile.update()
            updated = True
        #if updated or metafile.key not in volumedb:
        #    log.note("Writing %s to volumedb", metafile.key)
        #    volumedb[metafile.key] = metafile
        #    new = True
        if new or updated:
            #if options.persist_meta:
            #if metafile.non_zero:
            #    log.note("Overwriting previous metafile at %s", metafile.path)
            metafile.write()
            for k in metafile.data:
                print '\t'+k+':', metafile.data[k]
            print '\tSize: ', lib.human_readable_bytesize(
                metafile.data['Content-Length'], suffix_as_separator=True)
        else:
            print '\tOK'
    volume.store.sync()

#@Target.register(NS, 'meta', 'rsr:volume')
#def rsr_meta(src, pred, value, volume=None, *args):
def rsr_meta(volume=None, *args):
    """
    Get or set specific metadata.

        /volume/dir/ # rsr:meta ./file.avi rsr:media video/speech/lecture
        /volume/dir/ # rsr:meta ./book.pdf rsr:media text/book/technical

    """
    src = args.pop(0)
    pred = args.pop(0)
    value = args.pop(0)

    yield Arguments(args)

    vdb = volume.db

    # if exists, read,
    # otherwise look in shelve
    mf = Metafile.fetch(src, vdb)
    # if in shelve, mf may exist and is given quick sanity check




class Rsr(libcmd.StackedCommand):

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    assert NAME == 'rsr'
    DEFAULT_RC = 'cllct.rc'
    DEFAULT_CONFIG_KEY = NAME
    DEPENDS = {
            'rsr_volume': [ 'set_commands' ],
            'rsr_workspace': [ 'rsr_volume' ],
            'rsr_homedir': [ 'rsr_workspace' ],
            'rsr_session': [ 'rsr_homedir' ],
            'rsr_info': [ 'rsr_session' ],
            'rsr_show': ['rsr_session'],
            'rsr_assert': ['rsr_session'],
            'rsr_assert_group': ['rsr_session'],
            'rsr_assert_path': ['rsr_session'],
            'rsr_commit': ['rsr_session'],
            'rsr_remove': ['rsr_session'],
            'rsr_list': ['rsr_session'],
            'rsr_list_groups': ['rsr_session'],
            'rsr_nodes': ['rsr_session'],
            'rsr_tree': ['rsr_session'],
            'rsr_update': ['rsr_session'],
            'rsr_repo_update': ['rsr_session'],
        }

    DEFAULT_DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DEFAULT_DB_PATH
    DEFAULT_DB_SESSION = 'default'

    DEFAULT = [ 'rsr_info' ]

    @classmethod
    def get_optspec(Klass, inheritor):
        """
        Return tuples with optparse command-line argument specification.
        """
        p = inheritor.get_prefixer(Klass)
        return (
                # XXX: duplicates Options
                p(('-d', '--dbref'), { 'metavar':'URI',
                    'default': inheritor.DEFAULT_DB,
                    'dest': 'dbref',
                    'help': "A URI formatted relational DB access description "
                        "(SQLAlchemy implementation). Ex: "
                        " `sqlite:///taxus.sqlite`,"
                        " `mysql://taxus-user@localhost/taxus`. "
                        "The default value (%default) may be overwritten by configuration "
                        "and/or command line option. " }),
                p(('--repo',), {
                    'metavar':'NAME',
                    'default': "cllct",
                    'action': 'store',
                    'dest': 'repo',
                    'help': "Set data repository" }),
                p(('--session',), {
                    'metavar':'NAME',
                    'default': "default",
                    'action': 'store',
                    'dest': 'session',
                    'help': "Session determines working tree root" }),
                p(('--auto-commit',), {
#                    "default": False,
                    'action': 'store_true',
                    'help': "target" }),
                p(('-Q', '--query'), {'action':'callback',
                    'callback_args': ('query',),
                    'callback': libcmd.optparse_set_handler_list,
                    'dest': 'command',
                    'help': "TODO" }),
                p(('--init-db',), {
                    'dest': 'init_db',
                    'action': 'store_true',
                    'help': "Create database" }),

                p(('--init-volume',), {
                    'dest': 'init_volume',
                    'action': 'store_true',
                    'help': "(Re)set volume Id" }),
                p(('--init-workspace',), {
                    'dest': 'init_workspace',
                    'action': 'store_true',
                    'help': "(Re)set workspace Id" }),
                # commands
                p(('--info',), libcmd.cmddict(Klass.NAME, append=True)),
                p(('--volume',), libcmd.cmddict(Klass.NAME, append=True)),
                p(('--assert',), libcmd.cmddict(Klass.NAME, help="Add Node.")),
                p(('--assert-group',), libcmd.cmddict(Klass.NAME, help="Add Group-node.")),
                p(('--remove',), libcmd.cmddict(Klass.NAME, help="Drop Node.")),
                p(('--commit',), libcmd.cmddict(Klass.NAME, append=True)),
                p(('--nodes',), libcmd.cmddict(Klass.NAME)),
                p(('--set-root-bool',), libcmd.cmddict(Klass.NAME)),
                p(('--update',), libcmd.cmddict(Klass.NAME)),
                p(('--repo-update',), libcmd.cmddict(Klass.NAME)),
                #listtree?
                p(('-l', '--list',), libcmd.cmddict(Klass.NAME)),
                p(('-t', '--tree',), libcmd.cmddict(Klass.NAME)),
                p(('--list-groups',), libcmd.cmddict(Klass.NAME)),
                p(('--show',), libcmd.cmddict(Klass.NAME, help="Print Node.")),
            )

    def rsr_sessiondir(self, prog, opts):
        """
        Find the nearest session dir, and mark its use centrally.
        TODO: Session dirs are subclasses of metadirs. The resource module
        `res.session` helps to manage several kinds of them.
        """
        # Get the sessiondir, by default or specific kind
        sessiondir = None
        if opts.session == 'default':
            sessiondir = SessionDir.fetch(prog.pwd)
        else:
            sessiondirs = SessionDir.findAll(prog.pwd)
            for sdir in sessiondirs:
                if sdir.kind == opts.session:
                    sessiondir = sdir
        # Now update central
        # XXX: perhaps user metadir should be inited already,
        # the session will be inited later in rsr_session.. merge?
        userdir = UserDir.find(prog.pwd)
        c_store_ref = userdir.settings.dbref
        #SessionMixin.get_session('user', c_store_ref, doInit)
# XXX perhaps not open SA here, but dbm
#c_db = userdir.init_indices...
# There is no tool for that. res.session.UserDir?

    def rsr_volume(self, prog, opts):
        "Load volume configuration and return instance. "
        volume = res.Volumedir.fetch(prog.pwd)
        yield dict(volume=volume)
        #taxus.Volume.byKey()
        if opts.init_volume:
            volume.init(create=opts.init_volume)

    def rsr_workspace(self, prog, opts):
        "Load workspace configuration and return instance. "
        # pre-db session fetch retrieves directory
        workspace = res.Workspace.fetch(prog.pwd)
        yield dict(workspace=workspace)

    def rsr_homedir(self, prog, opts):
        "Load homedir configuration and return instance. "
        homedir = res.Homedir.fetch(prog.pwd)
        yield dict(homedir=homedir)
        #if opts.init_homedir:
        #    homedir.init(create=opts.init_homedir)

    def rsr_session(self, prog, volume, workspace, homedir, opts):
        """
        Determine context, and from there get the session/dbref to initialize an
        SQLAlchemy session.
        The context depends on the current working directory, and defaults to
        the nearest workspace; perhaps a volume or the homedir.
        """
        session = Session.init(prog.pwd, opts.session)
        log.note('Session: %s', session)
        assert session.context, opts.session
        prog.session = session
        yield dict(context=session.context)
        log.note('Context: %s', session.context)

        # SA session
        #dbref = session.context.settings.dbref
        #dbref = opts.dbref
        repo_root = session.context.settings.data.repository.root_dir
        repo_path = os.path.join(repo_root, opts.repo)

        from sa_migrate import custom
        config = custom.read(repo_path)
        repo_opts = custom.migrate_opts(repo_path, config)
        dbref = repo_opts['url']
        log.note('DBRef: %s', dbref)
        if opts.init_db:
            log.debug("Initializing SQLAlchemy session for %s", dbref)
        sa = SessionMixin.get_session(opts.session, dbref, opts.init_db)
        yield dict(sa=sa)

    def rsr_nodes(self, sa, *args):
        "Print existing nodes. "
        nodes = []
        for arg in args:
            typehint, nodeid = self.deref(arg, sa)
            # do something with typehint?
            node = Node.find(( Node.name == nodeid, ))
            if not node:
                log.warn("No entry for %s:%s", typehint, nodeid)
                continue
            print node.ntype, node.name
            nodes.append(node)
        yield dict(nodes=nodes)

    def rsr_info(self, prog, context, opts, sa, nodes):
        "Log some session statistics and info"
        log.note("SQLAlchemy session: %s", sa)
        models = taxus.core.ID, Node, Name, Tag, taxus.GroupNode, taxus.INode, taxus.Locator
        cnt = {}
        for m in models:
            cnt[m] = sa.query(m).count()
            log.note("Number of %s: %s", m.__name__, cnt[m])
        if 'node' in self.globaldict and self.globaldict.node:
            log.info("Auto commit: %s", opts.rsr_auto_commit)
            log.info("%s", self.globaldict.node)

    def deref(self, ref, sa):
        """
        <nodetype>:<nodeid>
        """
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

    def rsr_assert(self, sa=None, opts=None, *refs):
        """
        <node>
        <group>/<node> (node+path)
        <group>/<group> (group+path)

        <group root=true>/<group>/<node>
        """
        for ref in refs:
            nodetype, localpart = self.deref( ref, sa )
            #NodeType = getUtility(INameRegistry).lookup(nodetype)
            subh = 'rsr_assert_%s' % nodetype
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
            log.info("Added new node to session: %s", node)
            if opts.rsr_auto_commit:
                sa.commit()
        yield dict( node = node )
        log.note('Asserted %s', node)

    def rsr_assert_node( self, path, name ):
        self.execute( '_assert_node', dict( Klass=Node, name=name ) )
        if path:
            self.execute( 'rsr_assert_group', dict( path=path ))
            path = sep.join(( path, name ))
            self.execute( 'rsr_assert_path', dict( path=path ))

    def rsr_assert_group(self, path, sa=None, opts=None):
        """
        Assure Group with `name` exists (or any subtype).
        """
        assert path and isinstance( path, basestring )
        if sep in path:
            elems = path.split(sep)
            # Yield element strings
            while elems:
                elem = elems.pop(0)
                for x in self.rsr_assert_group( elem, sa, opts ):
                    yield x
            # Defer
            self.execute( 'rsr_assert_path', dict( path=path ) )
        else:
            for x in self._assert_node(GroupNode, path, sa, opts):
                yield x

    def rsr_assert_path(self, path, sa, opts):
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
        if opts.rsr_auto_commit:
            opts.commit()

    def rsr_remove(self, ref, sa, opts):
        "Remove a node"
        node = Node.find(( Node.name == ref, ))
        sa.delete( node )
        if opts.rsr_auto_commit:
            sa.commit()

    def rsr_commit(self, sa):
        "Commit changes to SQL"
        log.note("Committing SQL changes");
        sa.commit()
        log.debug("Commit finished");

    def rsr_show(self, ref_or_node, sa ):
        "Print a single node from name or path reference. "
        if isinstance( ref_or_node, basestring ):
            nodetype, localpart = self.deref(ref_or_node, sa)
            node = Node.find(( Node.name == localpart, ))
            print node

    def rsr_list(self, groupnode, volume=None, sa=None):
        "List all nodes, or nodes listed in group node"
        # XXX: how to match cmdline arg to nodes, alt notations for paths?
        #   filter on attr sytnax? @name= @parent.name=? see also deref.
        if groupnode:
            realnode = groupnode
            if os.path.exists( groupnode ):
                realnode = os.path.realpath( groupnode )
            groupnode = os.path.basename( realnode )
            group = GroupNode.find(( Node.name == groupnode, ))
            assert group
            print group.name
            for subnode in group.subnodes:
                print '\t', subnode.name
        else:
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

    def rsr_list_groups(self, sa=None):
        "List all group nodes"
        gns = sa.query(GroupNode).all()
        fields = 'node_id', 'name', 'subnodes'
        if gns:
            print '#', ', '.join(fields)
            for n in gns:
                for f in fields:
                    print getattr(n, f),
                print
        else:
            log.warn("No entries")

    def rsr_set_root_bool(self, sa=None, opts=None):
        """
        set bool = true
        where
            count(jt.node_id) == 0
            jt.group_id

        core.groupnode_node_table\
            update().values(
                )
        """
        gns = sa.query(GroupNode).all()
        if gns:
            for n in gns:
                if not n.supernode:
                    n.root = True
                    log.info("Root %s", n)
                    sa.add(n)
            if opts.rsr_auto_commit:
                sa.commit()
        else:
            log.warn("No entries")

    def rsr_update(self, sa, opts):
        self.execute('rsr_set_root_bool')

    def rsr_tree(self, sa=None, *nodes):
        "Print a tree of nodes as nested lists"
        if not nodes:
            roots = sa.query(GroupNode)\
                    .filter( GroupNode.root == True, ).all()
            if not roots:
                log.err("No roots")
        else:
            roots = []
            for node in nodes:
                group = GroupNode.find(( Node.name == node, ))
                if not group:
                    log.warn(group)
                    continue
                roots.append(group)
        for group in roots:
            self.execute( 'rsr_node_recurse', dict( group=group  ) )

    def rsr_node_recurse(self, sa, group, lvl=0):
        print lvl * '  ', group.name
        for sub in group.subnodes:
            self.rsr_node_recurse(sa, sub, lvl=lvl+1)

    def rsr_repo_update(prog=None, objects=None, opts=None):
        "TODO: move to vc, for walk see dev_treemap or re-think-use Dir.walk"
        i = 0
        for repo in res.Repo.walk(prog.pwd, max_depth=2):
            i += 1
            assert repo.rtype
            assert repo.path
            print repo.rtype, repo.path,
            if repo.uri:
                print repo.uri
            else:
                print


if __name__ == '__main__':
    Rsr.main()


