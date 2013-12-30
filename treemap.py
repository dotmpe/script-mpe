#!/usr/bin/env python
"""tree - Creates a tree of a filesystem hierarchy.

Calculates cumulative space of each directory. Output in JSON format.

Copyleft, May 2007.  B. van Berkum <berend `at` dotmpe `dot` com>

Updates
-------
October 2012
    - using blksize to calculate actual occupied disk space.
    - a too detailed storage will drag performance. The current operations
      per file are constant, so file count is the limiting factor.

TODO: the storage should create a report for some directory, sorry about
    threshold later.

"""
"""Create a tree of the filesystem using dicts and lists.

    All filesystem nodes are dicts so its easy to add attributes.
    One key is the filename, the value of this key is None for files,
    and a list of other nodes for directories. Eg::

        {'rootdir': [
            {'filename1':None},
            {'subdir':[
                {'filename2':None}
            ]}
        ]}
    """

"""

Caching structured

Filetree prototype: store paths in balanced, traversable tree structure 
for easy, fast and space efficient
index trees of filesystem (and other hierarchical structrures).

Introduction
______________________________________________________________________________
Why? Because filepath operations on the OS are generally far more optimized
than native code: only for extended sets some way of parallel (caching) 
structure may optimize performance. However since filesystem hierarchies are 
not balanced we want to avoid copying (parts) of the unbalanced structure to 
our index.

Operations on each file may be fairly constant when dealing with the descriptor,
or depend on file size. The calling API will need to determine when to create 
new nodes.

Treemap accumulates the filecount, disk usage and file sizes onto all directory
nodes in the tree. Conceptually it may be used as an enfilade with offsets and
widths?


Implementation
______________________________________________________________________________
Below is the code where Node implements the interface to the stored data,
and a separate Key implementation specifies the index properties of it.
Volume is the general session API which is a bit immature, but does store
and reload objects. Storage itself is a simple anydb with json encoded data.



"""
import sys
import os
import shelve
from pprint import pformat
from os import listdir, stat, lstat
from os.path import join, exists, islink, isdir, getsize, basename, dirname, \
    expanduser, realpath

import zope
from zope.component.factory import IFactory, Factory
from zope.component import \
        getGlobalSiteManager, \
        getUtility, queryUtility, createObject

import res.iface
import res.fs
import res.js
import res.primitive    


gsm = getGlobalSiteManager()


class TreeMapNode(res.primitive.TreeNodeDict):

    # Persistence methods

    def reload_data( self, parentdir, force_clean=None ):
        """
        Call this after initialization to compare the values to the 
        DB, and set the 'fresh' attribute.
        """
#        print 'reload', '-'*79, parentdir, self.name
        path = join( parentdir, self.name )
        clss = self.__class__
        if clss.is_stored( path ):
            data = clss.get_stored( path )
            # XXX: this is only needed for the rootnode which has a pull path
            assert os.sep not in self.__dict__, self.__dict__
            if path in data:
                data[ self.name ] = data[ path ]
                del data[ path ]
            # /XXX
            self.update( data )
#            print '+' * 79
#            print self.name, self.value
            if force_clean != None:
                self.fresh = force_clean
            elif os.path.exists( path ):
                cur_mtime = os.path.getmtime( path )
                self.fresh = self.mtime == cur_mtime
                if not self.fresh:
                    self.mtime = cur_mtime
            if self.value:
                assert os.sep not in self.value
                newvalue = []
                for subnode_name in self.value:
                    node_path = join( path, subnode_name )
                    # FIXME: should fs_node_init here
                    subnode = fs_node_init( node_path )
                    assert os.sep != subnode.name, subnode.name
                    if force_clean != None or self.fresh:
                        # assert os.path.exists
                        subnode.reload_data( path, self.fresh )
                    elif os.path.exists( node_path ):
                        subnode.reload_data( path )
                    newvalue.append( subnode ) # XXX: where to handle deletion
                self[ self.name ] = newvalue
#            print self.name, self.value
#        print '/reload', '-'*79, parentdir, self.name

    def commit( self, parentdir ):
        """
        Call this after running?
        Need to clean up non existant paths
        """
#        print 'commit', '-'*79, parentdir, self.name
        clss = self.__class__
        path = join( parentdir, self.name )
        data = self.copy()
        if '@fresh' in data:
            del data['@fresh']
        #or raise Exception( "Missing attr for %s" % path )
        assert os.sep not in data, data
        if data[ self.name ]:
            data[ self.name ] = [ subnode.name for subnode in self.value ]
            [ subnode.commit( path ) for subnode in self.value ]
        assert os.sep not in data, data
        clss.set_stored( path, data )

    # Static interface to shelved dictionaries

    storage = None

    @classmethod
    def set_stored( clss, path, node ):
        clss.storage[ path.encode() ] = node

    @classmethod
    def is_stored( clss, path ):
        return path.encode() in clss.storage

    @classmethod
    def get_stored( clss, path ):
        return clss.storage[ path.encode() ]

    def space( self, parent_path ):
        """
        Return the size in disk blocks taken by the filetree.
        """
        path = join( parent_path, self.name )
        if self.value:
            space = 0
            for node in self.value:
                space += node.space( path )
            return space
        elif islink( path ):
            return lstat( path ).st_blocks
        elif exists( path ):
            return stat( path ).st_blocks
        else:
            raise Exception( "Path does not exist: %s" % path )

    def size( self, parent_path ):
        """
        Return the size in bytes taken by the files in the filetree.
        XXX: does this count dirs?
        """
        path = join( parent_path, self.name )
        if self.value:
            size = 0
            for node in self.value:
                size += node.size( path )
            return size 
        elif islink( path ):
            return lstat( path ).st_size
        elif exists( path ):
            return stat( path ).st_size
        else:
            raise Exception( "Path does not exist: %s" % path )

    @property
    def isdir( self ):
        "Check for trailing '/' convention. "
        return self.name.endswith( os.sep )

    def files( self, parent_path ):
        "This does a recursive file count. "
        path = join( parent_path, self.name )
        if self.value:
            files = 0
            for node in self.value:
                files += node.files( path )
            return files
        else:
            return 1


    # Persistence methods
    # XXX: unused iface stubs here, see dev_treemap_tmp

    def reload_data( self, parentdir, force_clean=None ):
        """
        Call this after initialization to compare the values to the 
        DB, and set the 'fresh' attribute.
        """

    def commit( self, parentdir ):
        """
        Call this after running?
        Need to clean up non existant paths
        """



def find_parent( dirpath, subleaf, get_realpath=False ):
    if get_realpath:
        dirpath = realpath( dirpath )
    dirparts = dirpath.split( os.sep )
    while dirparts:
        path = join( *dirparts )
        if isdir( join( *tuple( dirparts )+( subleaf, ) ) ):
            return path
        dirparts.pop()

def find_volume( dirpath ):
    vol = find_parent( dirpath, '.volume' )
    if not vol:
        vol = find_parent( dirpath, '.volume', True )
    if vol:
        print "In volume %r" % vol
        vol = join( vol, '.volume' )
    else:
        vol = expanduser( '~/.treemap/' ) # XXX: *nix only
        if not exists( vol ):
            os.makedirs( vol )
        print "No volumes, treemap store at %r" % vol
    return vol


# old, figure out storage
def fs_node_init( path ):
#    print '\fs_node_init', '-'*79, path
    path = path.rstrip( os.sep )
    path2 = path
    if isdir( path ) and path[ -1 ] != os.sep:
        path2 += os.sep
    node = TreeMapNode( basename( path ) + ( isdir( path ) and os.sep or '' ) )
    if TreeMapNode.is_stored( path2 ):
        node.reload_data( dirname( path ) )
        return node
    else:
        return TreeMapNode( basename( path ) + ( isdir( path ) and os.sep or '' ) )
#    print '/fs_node_init', '-'*79, path


def fs_tree( dirpath, tree ):
    """Create a tree of the filesystem using dicts and lists.

    All filesystem nodes are dicts so its easy to add attributes.
    One key is the filename, the value of this key is None for files,
    and a list of other nodes for directories. Eg::

        {'rootdir': [
            {'filename1':None},
            {'subdir':[
                {'filename2':None}
            ]}
        ]}
    """
    assert dirpath
    assert tree.name
    fs_encoding = sys.getfilesystemencoding()
    path = join( dirpath, tree.name )
#    print '\\fs_tree', '-'*79, dirpath, tree.name
#    print isdir( path ), tree.fresh
    if isdir( path ) and not tree.fresh:
        update = {}
        if tree.value:
            for subnode in tree.value:
                if not exists( join( path, subnode.name ) ):
                    tree.remove( subnode )
                else:
                    update[ subnode.name ] = subnode
        for fn in listdir( path ):
            # Be liberal... take a look at non decoded stuff
            if not isinstance( fn, unicode ):
                # try decode with default codec
                try:
                    fn = fn.decode( fs_encoding )
                except UnicodeDecodeError:
                    print >>sys.stderr, "unable to decode:", path, fn
                    continue
            subpath = join( path, fn )
            if isdir( subpath ):
                fn += os.sep
#                print '\============',path, fn
            if fn in update:
                subnode = update[ fn ]
            else:
                subnode = fs_node_init( subpath )
                tree.append( subnode )
            fs_tree( path, subnode )
#            if isdir( subpath ):
#                print '/============',path, fn
#    print '/fs_tree', '-'*79, dirpath, tree.name


def fs_treesize( root, tree, files_as_nodes=True ):
    """Add 'space' attributes to all nodes.

    Root is the path on which the tree is rooted.

    Tree is a dict representing a node in the filesystem hierarchy.

    Size is cumulative for each folder. The space attribute indicates
    used disk space, while the size indicates actual bytesize of the contents.
    """
    if not root:
        root = '.' + os.sep
    assert root and isinstance( root, basestring ), root
    assert isdir( root ), stat( root )
    assert isinstance( tree, Node )
    # XXX: os.stat().st_blksize contains the OS preferred blocksize, usually 4k, 
    # st_blocks reports the actual number of 512byte blocks that are used, so on
    # a system with 4k blocks, it reports a minimum of 8 blocks.
    cdir = join( root, tree.name )
    if not tree.fresh or not tree.space or not tree.size:
        size = 0
        space = 0
        if tree.value:
            tree.count = len(tree.value)
            for node in tree.value: # for each node in this dir:
                path = join( cdir, node.name )
                if not exists( path ):
                    continue
                    raise Exception( path )
                if isdir( path ):
                    # subdir, recurse and add space
                    fs_treesize( cdir, node )
                    tree.count += node.count
                    space += node.space
                    size += node.size
                else:
                    # filename, add sizes
                    actual_size = 0
                    used_space = 0
                    try:
                        actual_size = getsize( path )
                    except Exception, e:
                        print >>sys.stderr, "could not get size of %s: %s" % ( path, e )
                    try:
                        used_space = lstat( path ).st_blocks * 512
                    except Exception, e:
                        print >>sys.stderr, "could not stat %s: %s" % ( path, e )
                    node.size = actual_size
                    node.space = used_space
                    size += actual_size
                    space += used_space
        else:
            tree.count = 0
        tree.size = size
        tree.space = space
    tree.space += ( stat( cdir ).st_blocks * 512 )


class TreeNodeHelper(object):
    def append(self, o):
        self.subnodes.append(o)
    def remove(self, o):
        self.subnodes.remove(o)
    # XXX may want to namepsace, specifiy attribute names and values too for easy handling

class TreeMap(TreeNodeHelper):
    """
    TODO: load from JSON, ie. load from something loaded into primitive ITreeNode impl.
    TODO: update length, space attributes based on OS.
    """

    zope.interface.implements(res.iface.ITreeNode)

    def __init__(self):
        pass

    def init(self, tree, opts):
        # XXX dust-off and subclass MetaDir and load last report on init?
        if tree:
            self.tree = tree
        else:
            self.tree = NullTree()
        # TODO tree is fresh while self.dirpath 'has not been updated'
    
    def attributes(self):
        # FIXME: if self.tree is fresh, return attr from dict
        return self.tree.attributes()

    def subnodes(self):
        # FIXME: if self.tree is fresh, return attr from dict
        return self.tree.subnodes()

    def update(self):
        """
        """
# FIXME: just implement the ITreeNode stuff for INode and let a visitor handle
# getting the data
        # move tree to in-memory TreeNodeDict, get space and size attrs too
        #tv = TreeVisitor( )
        # TODO visitor-type Clone: create tree from ITreeFactory and ITreeNode
        self.tree = res.primitive.TreeNodeDict()

        tv = res.helper.TreeCloner( res.helper.tree_factory( res.primitive.TreeNodeDict ) )
        tv.visit( self.tree )

# TODO visitor to set name/subnodes to TreeNodeDict, or to get them from INode tree
# same for space, size, time attr etc
# XXX other (dual-tree or parallel-tree) visitors to update one tree from another,
# or to trigger node methods
# XXX: how does a parallel-tree-visitor work

    def report(self, *mapfields):
        """
        IFile has length and space, 
        IDir has space and IHier rel. to other Node, and so also accumulated length and space.
        """
        # XXX
        #vstr = IVisitor(.. mapfields ..)
        #v = ITreeVisitor( self.tree, vstr )
        #v.visit( self.inode )


treemap_factory = Factory(TreeMap, 'TreeMap')

gsm.registerUtility(treemap_factory, IFactory, 'treemap')

#queryUtility(IFactory, 'treemap')()
#createObject('treemap')



def usage(msg=0):
    print """%s
Usage:
    %% treemap.py [opts] directory

Opts:
    -d, --debug        Plain Python printing with total size data.
    -j, -json          Write tree as JSON.
    -J, -jsonxml       Transform tree to more XML like container hierarchy befor writing as JSON.

    """ % sys.modules[__name__].__doc__
    if msg:
        msg = 'error: '+msg
    sys.exit(msg)


def main():
    # Script args
    import confparse
    opts = confparse.Values(dict(
            fs_encoding = sys.getfilesystemencoding(),
            voldir = None,
            debug = None,
        ))
    argv = list(sys.argv)

    treepath = argv.pop()
    if not basename(treepath): 
        # strip trailing os.sep
        treepath = treepath[:-1]
    assert basename(treepath) and isdir(treepath), \
            usage("Must have dir as last argument")
    path = opts.treepath = treepath

    for shortopt, longopt in ('d','debug'), ('j','json'), ('J','jsonxml'):
        setattr(opts, longopt, ( '-'+shortopt in argv and argv.remove( '-'+shortopt ) == None ) or (
                '--'+longopt in argv and argv.remove( '--'+longopt ) == None ))

    # Get shelve for storage
    if not opts.voldir:
        opts.voldir = find_volume( path )
    storage = TreeMapNode.storage = shelve.open( join( opts.voldir, 'treemap.db' ) )

    ### Init FileTree and TreeMap

    # zac
#    nodetree = getUtility(res.iface.IDir).tree( path, opts )
#    #nodetree = INode( path )
#    treemap = createObject('treemap')
#    treemap.init( nodetree, opts )
#    treemap.report(':count', 'length', 'space')
#
#    return
#
#    # wrong, passing-down-arguments approach ("facade")
#    treemap = TreeMap(path)
#    treemap.tree( opts )
#
#    return

    # Walk filesystem, updating where needed
    tree = fs_node_init( path )
    print tree
    fs_tree( dirname( path ), tree )
#    print 'prefix', tree.prefix
#    print 'dir', dir(tree)
#    print 'dict', tree.__dict__
    print 'fs_tree', pformat(tree.copy())
    return

    # Add space attributes
#    fs_treesize( dirname( path ), tree )


    ### Update storage

    # Set proper root path, and output
    tree.name = path + os.sep
#    fs_treemap_write( debug, tree )
    #print 'fs_treemap_write', pformat(tree)
    tree.commit( dirname( path ) )
#    print storage[ path + os.sep ]
#    for fn in listdir( path ):
#        sub = join( path, fn )
#        if isdir( sub ):
#            sub += os.sep
#        print storage[ sub ]
    storage.close()


def fs_treemap_write( opts, tree ):
    ### Output
    if res.js.dumps and ( opts.json and not opts.debug ):
        print res.js.dumps( tree )

    elif res.js.dumps and ( opts.jsonxml and not opts.debug ):
        tree = res.primitive.translate_xml_nesting(tree)
        print res.js.dumps( tree )

    else:
        if not res.js.dumps:
            print >>sys.stderr, 'Error: No JSON writer.'
        print pformat(tree.copy())
        total = float( tree.size )
        used = float( tree.space )
        print 'Tree size:'
        print tree.size, 'bytes', tree.count, 'items'
        print 'Used space:'
        print tree.space, 'B'
        print used/1024, 'KB'
        print used/1024**2, 'MB'
        print used/1024**3, 'GB'


if __name__ == '__main__':

    main()


