#!/usr/bin/env python
"""treemap - Creates a tree of a filesystem hierarchy.

Calculates cumulative size of each directory. Output in JSON format.

TODO: store local and cumulative values in TreeMap or FileTreeMap document.
    - build ``hashref(path)`` -> local, cumulative lookup
      TODO: this index would be a some URIref map
    - must store nodes for all paths, can store one or more dates per tree
XXX: started using Document Node in filetree.py

Copyleft, May 2007.  B. van Berkum <berend `at` dotmpe `dot` com>
"""
import sys
from os import listdir
from os.path import join, isdir, getsize, basename, dirname
from pprint import pformat
import res.js
import res.primitive    


class Node(res.primitive.TreeNodeDict):
    pass


def fs_tree(dir):
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
    fs_encoding = sys.getfilesystemencoding()
    dirname = basename(dir)
    tree = Node(dirname)
    for fn in listdir(dir):
        # Be liberal... take a look at non decoded stuff
        if not isinstance(fn, unicode):
            # try decode with default codec
            try:
                fn = fn.decode(fs_encoding)
            except UnicodeDecodeError:
                print >>sys.stderr, "corrupt path:", dir, fn
                continue
        # normal ops
        path = join(dir, fn)
        if isdir(path):
            # Recurse
            tree.append(fs_tree(path))
        else:
            tree.append(Node(fn))

    return tree

def fs_treesize(root, tree, files_as_nodes=True):
    """Add 'size' attributes to all nodes.

    Root is the path on which the tree is rooted.

    Tree is a dict representing a node in the filesystem hierarchy.

    Size is cumulative.
    """
    assert isinstance(root, basestring) and isdir(root), repr(root)
    assert isinstance(tree, Node)

    if not tree.size:
        dir = join(root, tree.name)
        size = 0
        if tree.value:
            for node in tree.value: # for each node in this dir:
                path = join(dir, node.name)
                if isdir(path):
                    # subdir, recurse and add size
                    fs_treesize(dir, node)
                    size += node.size
                else:
                    # filename, add size
                    try:
                        csize = getsize(path)
                        node.size = csize
                        size += csize
                    except:
                        print >>sys.stderr, "could not get size of %s" % path
        tree.size = size

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
    # strip trailing os.sep
    if not basename(treepath): 
        treepath = treepath[:-1]
    assert basename(treepath) and isdir(treepath), \
            usage("Must have dir as last argument")
    path = opts.treepath = treepath

    for shortopt, longopt in ('d','debug'), ('j','json'), ('J','jsonxml'):
        setattr(opts, longopt, ( '-'+shortopt in argv and argv.remove( '-'+shortopt ) == None ) or (
                '--'+longopt in argv and argv.remove( '--'+longopt ) == None ))

    # Walk filesystem
    tree = fs_tree(path)

    # Add size attributes
    fs_treesize(path, tree)

    # Set proper root path
    tree.name = path

    ### Output
    if res.js.dumps and ( opts.json and not opts.debug ):
        print rs.js.dumps(tree)

    elif res.js.dumps and ( opts.jsonxml and not opts.debug ):
        tree = translate_xml_nesting(tree)
        print res.js.dumps(tree)

    else:
        print >>sys.stderr, 'No JSON.'
        print pformat(tree)
        total = float(tree.size)
        print 'Tree size:'
        print total, 'B'
        print total/1024, 'KB'
        print total/1024**2, 'MB'
        print total/1024**3, 'GB'


def translate_xml_nesting(tree):
    newtree = {'children':[]}
    for k in tree:
        v = tree[k]
        if k.startswith('@'):
            if v:
                assert isinstance(v, (int,float,basestring)), v
            assert k.startswith('@'), k
            newtree[k[1:]] = v
        else:
            assert not v or isinstance(v, list), v
            newtree['name'] = k
            if v:
                for subnode in v:
                    newtree['children'].append( translate_xml_nesting(subnode) )
    assert 'name' in newtree and newtree['name'], newtree
    if not newtree['children']:
        del newtree['children']
    return newtree


if __name__ == '__main__':

    main()


