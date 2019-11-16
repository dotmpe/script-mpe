#!/usr/bin/env python
"""
See treemap.py, cutting out res for testing
"""
from __future__ import print_function
import sys
from time import time
from os import stat, listdir, sep
from os.path import join, isdir, isfile, islink, getsize, basename, dirname, \
        realpath, exists, expanduser, getctime, getmtime
from pprint import pprint
import pickle


__version__ = '0.0.4-dev' # script-mpe
__usage__ = """

Usage:
  treemap3.py [options] info [DIR]
  treemap3.py [options] count [--simple|--tree] DIR
  treemap3.py [options] size [--simple|--tree] PATH
  treemap3.py [options] tree DIR
  treemap3.py [options] check DIR
  treemap3.py [options] update [DIR]
  treemap3.py -h|--help|help
  treemap3.py --version

Options:
    --filename-encoding CODEC
                  [default: ascii]
    -O FMT, --output-format FMT
                  [pretty, none, repr, json, list] [default: pretty]
    -H, --human-readable
                  Print bytes as float for largest ISO unit prefix starting at
                  kilo and up all to yotta [KMGTPEZY].
    --cache-count-threshold x
                  [default: 1024]
    --cache-size-threshold yM
                  Start writing <basedir> size.int or json at x files, y megabytes
                  [default: 1024]
    --init        ..
    --update      ..
    --tree        Print tree in output format before standard command output.
    --simple      Don't build a tree or caches, accumulated just the size.
    -h --help     Show this usage description. For a command and argument
                  description use the command 'help'.
    --version     Show version (%s).

""" % ( __version__ )
__doc__ += __usage__

from script_mpe.libhtd import *
from script_mpe.lib import human_readable_float


cmd_default_settings = dict(
        HOME=expanduser('~'),
        quiet=False,
        no_cache=False,
        filename_encoding='ascii',
        default_output_format='pretty'
    )


def fs_dirnode( path, fs_encoding ):
    return dict(
            name=path,
            entries=[]
        )

def fs_filenode( path, fs_encoding ):
    return dict(
            name=path,
        )

def fs_node( path, fs_encoding ):
    nodename = basename( path )
    mode = None
    if exists(path): mode = stat(path).st_mode
    return dict(
            name=nodename,
            mode=mode
        )


def fs_infonode( tree, path, treeinfo ):
    key = path.replace(sep, '-').strip('-')
    treeinfo[key] = {
            'timestamp': time(),
            'ctime': getctime(path),
            'mtime': getmtime(path),
            'file-count': tree['content-count'],
            'content-size': tree['content-size']
        }


def fs_tree( path, fs_encoding, tree=None ):
    """Create a tree of the filesystem using dicts and lists.

    All filesystem nodes are dicts so its easy to add attributes
    for other purposes

    One key is the filename, the value of this key is None for files,
    and a list of other nodes for directories. Eg::

        [
            {'name':'filename1'},
            {'name':'subdir',
             'entries':[
                {'filename2':None}
            ]}
        ]
    """
    assert isdir( path )
    dirname = basename( path )
    if not tree:
        if tree == None:
            tree = fs_dirnode( dirname, fs_encoding )
        else:
            tree.update(fs_dirnode( dirname, fs_encoding ))

    for fn in listdir( path ):
        # Be liberal... take a look at non decoded stuff
        if not isinstance(fn, unicode):
            # try decode with default codec
            try:
                fn = fn.decode(fs_encoding)
            except UnicodeDecodeError:
                print("corrupt path:", path, fn, file=sys.stderr)
                continue
        # normal ops
        _path = join( path, fn )
        if islink(_path):
            pass #tree['entries'].append(fs_node(_path, fs_encoding))
        elif isdir(_path):
            # Recurse
            tree['entries'].append(fs_tree(_path, fs_encoding))
        elif isfile(_path):
            tree['entries'].append(fs_filenode(fn, fs_encoding))
        else:
            tree['entries'].append(fs_node(_path, fs_encoding))

    return tree


def fs_update( tree, fs_encoding, path ):

    files = listdir( path )
    # Remove deleted
    for entry in tree['entries']:
        _path = join( path, entry['name'] )
        pass
    # Add new
    # Update size


def fs_filecount( tree, fs_encoding, path ):

    files = listdir( path )
    # Remove deleted
    for entry in tree['entries']:
        _path = join( path, fn )
        pass
    # Add new
    # Update size


def fs_filesize( node, resolve_symlinks=False, path=None ):

    if not path:
        path = node['name']

    if resolve_symlinks:
        path = realpath(path)

    try:
        bytesize = getsize(path)
        node['content-size'] = bytesize
        return bytesize
    except Exception as e:
        print("could not get size of %s: %r" % (path, e),
                file=sys.stderr)


def fs_treecount( tree, resolve_symlinks=False, path=None ):

    if 'content-count' not in tree:
        count = 0
        if 'entries' in tree:
            if not path:
                path = tree['name']

            for node in tree['entries']: # for each node in this dir:
                subpath = join(path, node['name'])

                if islink(subpath):
                    pass

                elif isdir(subpath):
                    # subdir, recurse and add count
                    fs_treecount( node, resolve_symlinks, subpath )
                    count += node['content-count']

                else:
                    count += 1

        else:
            count += 1

        tree['content-count'] = count


def fs_treesize( tree, resolve_symlinks=False, path=None ):

    """Add 'content-size' attributes to all nodes.

    This reports on actual file (or symlink) contents, not filename allocation.
    The value is cumulative.

    Nodes in given tree must exists.
    """

    if 'content-size' not in tree:
        size = 0
        if 'entries' in tree:
            if not path:
                path = tree['name']

            for node in tree['entries']: # for each node in this dir:
                subpath = join(path, node['name'])

                if islink(subpath):
                    pass

                elif isdir(subpath):
                    # subdir, recurse and add size
                    fs_treesize( node, resolve_symlinks, subpath )
                    size += node['content-size']

                else:
                    # filename, add size
                    v = fs_filesize( node, resolve_symlinks, subpath )
                    if v: size += v

        else:
            v = fs_filesize( tree, resolve_symlinks, path )
            if v: size += v

        tree['content-size'] = size


def fs_fetchcount(DIR, g):
    """
    Simple file-counter, using no struct but one int. No caching.
    """
    count = 0

    if islink(DIR):
        pass

    elif isdir(DIR):
        for fn in listdir( DIR ):
            if not isinstance(fn, unicode):
                # try decode with default codec
                try:
                    fn = fn.decode(g.filename_encoding)
                except UnicodeDecodeError:
                    print("corrupt path:", DIR, fn, file=sys.stderr)
                    continue
            _path = join( DIR, fn )
            if islink(_path):
                pass
            elif isdir(_path):
                # Recurse
                count += fs_fetchcount(_path, g)
            elif isfile(_path):
                count += 1

    return count


def fs_fetchsize(PATH, g):
    """
    Simple accumulator for filesystem content-size, using no struct but one
    int. No caching.
    """
    size = 0

    if islink(PATH):
        pass

    elif isdir(PATH):
        for fn in listdir( PATH ):
            if not isinstance(fn, unicode):
                # try decode with default codec
                try:
                    fn = fn.decode(g.filename_encoding)
                except UnicodeDecodeError:
                    print("corrupt path:", PATH, fn, file=sys.stderr)
                    continue
            # normal ops
            _path = join( PATH, fn )
            if islink(_path):
                pass
                #if exists(_path):
                #    size += getsize(_path)
            elif isdir(_path):
                # Recurse
                size += fs_fetchsize(_path, g)
            elif isfile(_path):
                size += getsize(_path)

    else:
        size = getsize(PATH)

    return size


def fs_buildcount(DIR, g):
    tree, cache_fn = fs_loadcache(DIR, g)

    if not tree or g.update:
        if tree:
            fs_update( tree, g.filename_encoding, DIR )
        else:
            fs_tree( DIR, g.filename_encoding, tree )

        fs_treecount( tree, g.filename_encoding, DIR )
        fs_savecache( tree, cache_fn, g )
    return tree, tree['content-count']


def fs_buildsize(PATH, g):
    tree, cache_fn = fs_loadcache(PATH, g)
    if not tree or g.update:
        if tree:
            fs_update( tree, g.filename_encoding, PATH )
        else:
            fs_tree( PATH, g.filename_encoding, tree )
        fs_treesize( tree, g.filename_encoding, PATH )
        fs_savecache( tree, cache_fn, g )
    return tree, tree['content-size']


def fs_loadcache(PATH, g):
    cache_fn = join(PATH, '.cllct', 'treemap.pyp')
    if not exists(cache_fn):
        if not g.init:
            KEY = PATH.replace(sep, '-').strip('-')
            cache_fn = join(g.HOME, '.local', 'var', 'treemap', KEY+'.pyp')

    if not exists(cache_fn):
        tree = {}
    else:
        with open(cache_fn, 'rb') as f:
            tree = pickle.load(f)

    return tree, cache_fn


def fs_savecache(tree, cache_fn, g):
    with open(cache_fn, 'wb') as f:
        pickle.dump(tree, f, pickle.HIGHEST_PROTOCOL)


def fs_loadinfo(tree, g):
    treeinfo_fn = join(g.HOME, '.local', 'var', 'treemap', '__info__.pyp')
    if exists(treeinfo_fn):
        with open(treeinfo_fn, 'rb') as f:
            treeinfo = pickle.load(f)
    else:
        treeinfo = {}

    return treeinfo


def fs_saveinfo(tree, g):
    treeinfo_fn = join(g.HOME, '.local', 'var', 'treemap', '__info__.pyp')
    with open(treeinfo_fn, 'wb') as f:
        pickle.dump(tree, f, pickle.HIGHEST_PROTOCOL)


def fs_summarize(tree, g, base, treeinfo):
    if not treeinfo: treeinfo = fs_loadinfo(tree, g)

    if tree['content-size'] > g.cache_size_threshold:
        fs_infonode(tree, base, treeinfo)
    elif 'entries' in tree:
        if tree['content-count'] > g.cache_count_threshold:
            fs_infonode(tree, base, treeinfo)

    for path, node in fs_yieldpairs(tree, base, g):
        if 'entries' in node:
            fs_summarize(node, g, path, treeinfo)
    return treeinfo


def fs_yieldpairs(tree, base, g):
    if 'entries' in tree:
        for node in tree['entries']:
            path = join(base, node['name'])
            if 'entries' in node:
                for y in fs_yieldpairs(node, path, g): yield y
            else:
                yield path, node


def fs_yieldpaths(tree, base, g):
    for path, node in fs_yieldpairs(tree, base, g):
        yield path


def fs_printpaths(tree, base, g):
    for path in fs_yieldpaths(tree, base, g):
        print(path)


def fs_printtree(tree, g):
    of = g.output_format.lower()
    if of == 'json':
        print(res.js.dumps(tree))
    elif of == 'repr':
        print(repr(tree))
    elif of == 'pretty':
        pprint(tree)
    elif of == 'list':
        fs_printpaths(tree, '', g)
    else: return 1



### CLI Subcommands

def cmd_info(DIR, g, opts):
    tree, cache_fn = fs_loadcache(DIR, g)

    print(cache_fn)


def cmd_count(DIR, g, opts):

    """
    """

    assert isdir(DIR)
    if g.simple:
        count = fs_fetchcount(DIR, g)
    else:
        tree, count = fs_buildcount(DIR, g)
        if g.tree:
            fs_printtree(tree, g)
         #if g.map:
         #    treeinfo = fs_summarize(tree, g)

    print(count)


def cmd_size(PATH, g, opts):

    """
    Gather cumulative size from tree, or by simply reading filesystem.

    --simple
        Get only cumulative size, without building tree or caching.
    """

    if g.simple:
        size = fs_fetchsize(PATH, g)
    else:
        tree, size = fs_buildsize(PATH, g)
        if g.tree:
            fs_printtree(tree, g)
         #if g.map:
         #    treeinfo = fs_summarize(tree, g)

    if g.human_readable:
        print(human_readable_float(size))
    else:
        print(size)


def cmd_tree(DIR, g, opts):

    """
    Build and print tree.
    """

    tree = fs_tree(DIR, g.filename_encoding)
    fs_printtree(tree, g)


def cmd_check(DIR, g, opts): pass


def cmd_update(DIR, g, opts):

    """
    Update local cache ()
    """

    #g.update = 1
    #if g.count:
    #else:
    #cmd_size(DIR, g)
    tree, cache_fn = fs_buildcount(DIR, g)
    tree, cache_fn = fs_buildsize(DIR, g)

    #tree, cache_fn = fs_loadcache(DIR, g)
    treeinfo = fs_summarize(tree, g, DIR, {})
    pprint(treeinfo)



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings
    libcmd_docopt.defaults(opts)
    opts.flags.cache_size_threshold = int(opts.flags.cache_size_threshold)
    opts.flags.cache_count_threshold = int(opts.flags.cache_count_threshold)
    opts.flags.update(cmd_default_settings)
    opts.flags.update(
        default_output_format = not (
                '-O' in opts.argv or '--output-format' in opts.argv ),
    )
    return init

def main(opts):

    """
    Execute command.
    """
    global commands

    settings = opts.flags

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    global __version__
    return '%s' % __version__


if __name__ == '__main__':
    import sys
    argv = sys.argv[1:]
    if not argv: argv = [ 'list' ]
    opts = libcmd_docopt.get_opts(__doc__, version=get_version(), argv=argv,
            defaults=defaults)
    sys.exit(main(opts))
