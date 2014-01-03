from fnmatch import fnmatch
import os
from os.path import join 
import re

from script_mpe import confparse
from script_mpe import log
from script_mpe.lib import Prompt


PATH_R = re.compile("[A-Za-z0-9\/\.,\[\]\(\)_-]")


class INode(object):

    def __init__(self, path):
        self.path = path

    @classmethod
    def getsubclass( Klass, path ):
        nodetype = StatCache.getnodetype( path )
        assert nodetype, path
        for SubClass in Klass.__subclasses__():
            if SubClass.implements == nodetype:
                return SubClass
        assert False, nodetype

    @classmethod
    def decode_path( Klass, path, opts ):
        return path
        # XXX: decode from opts.fs_enc
        assert isinstance(path, basestring)
        try:
            path = unicode(path, 'utf-8')
            #path = path.decode('utf-8')
        except UnicodeDecodeError, e:
            log.warn("Ignored non-unicode path %s", path)
        finally:
            assert isinstance(path, unicode)
        return path


class File(INode):
    implements = 'file'

    ignore_names = (
            '._*',
            '.crdownload',
            '.DS_Store',
            '*.swp',
            '*.swo',
            '*.swn',
            '*.r[0-9]*[0-9]',
            '.git*',
            '*.pyc',
            '*~',
            '*.tmp',
            '*.part',
            '*.crdownload',
            '*.incomplete',
            '*.torrent',
            '*.uriref',
            '*.meta',
            '.symlinks'
        )

    ignore_paths = (
            '.Trashes*',
            '.TemporaryItems*',
            '*.git',
            '.git*',
        )

    @classmethod
    def ignored(klass, path):
        """
        File.ignored checks names and paths of files with ignore patterns.
        """
        for p in klass.ignore_paths:
            if fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
            if fnmatch(name, p):
                return True


pathdepth = lambda s: s.strip('/').count('/')

def exclusive ( opts, filters ):
    """
    Exclusive boolean list: only one may be true, 
    any combination of False and None allowed.
    """
    # verify: only one may be true
    x = None
    while not x:
        for n in filters.split(' '):
            if opts[n] == True:
                x = n
        break
    if x:
        for n in filters.split(' '):
            if n == x:
                continue
            assert not opts[n], ('conflict', n, opts[n], x)
    # set 
    if x:
        for n in filters.split(' '):
            if n == x:
                continue
            assert opts[n] == None, n
            opts[n] = False
    else:
        for n in filters.split(' '):
            if opts[n] == None:
                opts[n] = True


class Dir(INode):
    implements = 'dir'

    ignore_names = (
            '._*',
            '.metadata',
            '.conf',
            'RECYCLER',
            '.TemporaryItems',
            '.Trash*',
            '.cllct',
            'System Volume Information',
            'Desktop',
            'project',
            'sam*bup*',
            '*.bup',
            '.git*',
        )

    ignore_paths = (
            '*.git',
        )

    @classmethod
    def init(klass, ignore_file=None, ignore_defaults=None):
        """

        XXX
        Without calling init, Dir class works with static or run-time data only.

        Upon providing an ignore file name, both %path.paths %ignore_file.dirs
        """
        pass

    @classmethod
    def sane( klass, path ):
        return PATH_R.match( path )

    @classmethod
    def ignored(klass, path):
        for p in klass.ignore_paths:
            if fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
            if fnmatch(name, p):
                return True

    @classmethod
    def prompt_recurse(clss, opts):
        v = Prompt.query("Recurse dir?", ("Yes", "No", "All"))
        if v is 2:
            opts.recurse = True
            return True
        elif v is 0:
            return True
        return False

    @classmethod
    def prompt_ignore(clss, opts):
        v = Prompt.query("Ignore dir?", ["No", "Yes"])
        return v is 1

    @classmethod
    def check_ignored(Klass, filepath, opts):
        #if os.path.islink(filepath) or not os.path.isfile(filepath):
        if os.path.islink(filepath) or ( not os.path.isfile(filepath) and not os.path.isdir(filepath)) :
            log.warn("Ignored non-regular path %r", filepath)
            return True
        elif Klass.ignored(filepath) or File.ignored(filepath):
            log.info("Ignored file %r", filepath)
            return True

    @classmethod
    def check_recurse(Klass, dirpath, opts):
        #if not opts.recurse and not opts.interactive:
        #    return False
        depth = dirpath.strip('/').count('/')
        if Klass.ignored(dirpath):
            log.info("Ignored directory %r", dirpath)
            return False
        elif opts.max_depth != -1 and depth+1 >= opts.max_depth:
            log.info("Ignored directory %r at level %i", dirpath, depth)
            return False
        elif opts.recurse:
            return True
        elif opts.interactive:
            log.info("Interactive walk: %s",dirpath)
            if Klass.prompt_recurse(opts):
                return True
            elif Klass.prompt_ignore(opts):
                assert False, "TODO: write new ignores to file"

    walk_opts = confparse.Values(dict(
        interactive=False,
        recurse=False,
        max_depth=-1,
        include_root=False,
        # custom filters:
        exists=None, # True, False for exclusive path-exists, or None for either
        # None for include, False for exclude, True for exclusive:
        dirs=None, 
        files=None, 
        symlinks=None,
        links=None,
        pipes=None,
        blockdevs=None,
    ))
    
    @classmethod
    def walk(Klass, path, opts=walk_opts, filters=(None,None)):
        """
        Build on os.walk, this goes over all directories and other paths
        non-recursively.
        It returns all full paths according to walk-opts.
        FIXME: could, but does not, yield INode subtype instances.
        XXX: filters, see dev_treemap
        """
        if not isinstance(opts, confparse.Values):
            opts_ = confparse.Values(Klass.walk_opts)
            opts_.update(opts)
            opts = opts_
        else:
            opts = confparse.Values(opts.copy())
        # FIXME: validate/process opts or put filter somewhere
        if opts.max_depth > 0:
            assert opts.recurse
        exclusive( opts, 'dirs files symlinks links pipes blockdevs' )
        assert isinstance(path, basestring), (path, path.__class__)
        dirpath = None
        if not os.path.isdir( path ):
            if not opts.exists:
                log.err("Cannot walk non-dir path while os.stat is off. ")
            else:
                yield path
        else:
            if opts.dirs and opts.include_root:
                yield unicode( path, 'utf-8' )
            for root, dirs, files in os.walk(path):
                for node in list(dirs):
                    if not opts.recurse and not opts.interactive:
                        dirs.remove(node)
                    if not opts.dirs:
                        continue
                    dirpath = join(root, node)
                    #dirpath = os.path.join(root, node).replace(path,'').lstrip('/') +'/'
                    depth = pathdepth(dirpath.replace(path, ''))
                    if not os.path.exists(dirpath):
                        log.err("Error: reported non existant node %s", dirpath)
                        if node in dirs: dirs.remove(node)
                        continue
                    elif Klass.check_ignored(dirpath, opts):
                        if node in dirs: dirs.remove(node)
                        continue
                    elif not Klass.check_recurse(dirpath, opts):
                        if node in dirs:
                            dirs.remove(node)
#                    continue # exception to rule excluded == no yield
# caller can sort out wether they want entries to subpaths at this level
                    assert isinstance(dirpath, basestring)
                    try:
                        dirpath = unicode(dirpath)
                    except UnicodeDecodeError, e:
                        log.err("Ignored non-ascii/illegal filename %s", dirpath)
                        continue
                    assert isinstance(dirpath, unicode)
                    try:
                        dirpath.encode('ascii')
                    except UnicodeDecodeError, e:
                        log.err("Ignored non-ascii filename %s", dirpath)
                        continue
                    dirpath = Klass.decode_path(dirpath, opts)
                    yield dirpath
                for leaf in list(files):
                    filepath = join(root, leaf)
                    if not os.path.exists(filepath):
                        log.err("Error: non existant leaf %s", filepath)
                        if opts.exists != None and not opts.exists:
                            if opts.files:
                                yield filepath
                        else:
                            files.remove(leaf)
                        continue
                    elif Klass.check_ignored(filepath, opts):
                        log.info("Ignored file %r", filepath)
                        files.remove(leaf)
                        continue
                    filepath = Klass.decode_path(filepath, opts)
                    if not opts.files: # XXX other types
                        continue
                    #try:
                    #    filepath.encode('ascii')
                    #except UnicodeEncodeError, e:
                    #    log.err("Ignored non-ascii/illegal filename %s", filepath)
                    #    continue
                    yield filepath


class CharacterDevice(INode):
    implements = 'chardev'
class BlockDevice(INode):
    implements = 'blkdev'
class SymbolicLink(INode):
    implements = 'symlink'
class FIFO(INode):
    implements = 'fifo'
class Socket(INode):
    implements = 'socket'


