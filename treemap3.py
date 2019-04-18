#!/usr/bin/env python
"""
See treemap.py, cutting out res for testing
"""
from __future__ import print_function
import sys
from os import stat, listdir, sep
from os.path import join, isdir, isfile, islink, getsize, basename, dirname, \
        realpath
from pprint import pprint

__version__ = '0.0.4-dev' # script-mpe
__usage__ = """

Usage:
  treemap3.py [options] tree DIR
  treemap3.py [options] size PATH
  treemap3.py -h|--help|help
  treemap3.py --version

Options:
    -H, --human-readable
                  Print bytes as float for largest ISO unit prefix starting at
                  kilo and up all to yotta [KMGTPEZY].
    -h --help     Show this usage description. For a command and argument
                  description use the command 'help'.
    --version     Show version (%s).

""" % ( __version__ )
__doc__ += __usage__

from script_mpe.libhtd import *
from script_mpe.lib import human_readable_float


cmd_default_settings = dict(
        quiet=False,
        default_output_format=False
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
    return dict(
            name=nodename,
            mode=stat(path).st_mode
        )


def fs_tree( path, fs_encoding ):
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
    # FIXME:
    dirname = basename( path )
    tree = fs_dirnode( dirname, fs_encoding )

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
        #if islink(_path):
        #    pass
        if isdir(_path):
            # Recurse
            tree['entries'].append(fs_tree(_path, fs_encoding))
        elif isfile(_path):
            tree['entries'].append(fs_filenode(fn, fs_encoding))
        else:
            tree['entries'].append(fs_node(_path, fs_encoding))

    return tree


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

                if isdir(subpath):
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



### CLI Subcommands

def cmd_tree(DIR, g, opts):
    pprint(fs_tree(DIR, 'ascii'))


def cmd_size(PATH, g, opts):
    """
    Report on cumulative content length, expressed in bytes. This includes
    sysmlink content but not allocation for filesystem table.
    """

    if isdir(PATH):
        tree = fs_tree(PATH, 'ascii')
        fs_treesize(tree, False, PATH)
        size = tree['content-size']

    else:
        size = getsize(PATH)

    if g.human_readable:
        print(human_readable_float(size))
    else:
        print(size)


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings
    libcmd_docopt.defaults(opts)
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
