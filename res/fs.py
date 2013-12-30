from fnmatch import fnmatch
import os
from os.path import join 
import re
import stat

from confparse import Values
import log
from lib import Prompt


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
        # XXX: decode from opts.fs_enc
        assert isinstance(path, basestring)
        try:
            path = unicode(path, 'utf-8')
            #path = path.decode('utf-8')
        except UnicodeDecodeError, e:
            log.warn("Ignored non-unicode path %s", path)
        finally:
            assert isinstance(path, unicode)
        #try:
        #    path.encode('ascii')
        #except UnicodeDecodeError, e:
        #    log.warn("Ignored non-ascii path %s", path)
        #log.warn("Ignored non-ascii/illegal filename %s", filepath)
        #    continue
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
        )

    ignore_paths = (
            '*.pyc',
            '*~',
            '*.part',
            '*.incomplete',
            '*.crdownload',
        )

    include_paths = (
            '*.ogg', 
            '*.mp3', 
            '*.jpg', 
            '*.pdf', 
            '*.mkv', 
            '*.mp4', 
            '*.wmv', '*.mpg', '*.avi'
        )
    include_names = (
        )

    @classmethod
    def sane(klass, path):
        return PATH_R.match(path)

    @classmethod
    def include(klass, path):
        for p in klass.include_paths:
            if fnmatch(path, p):
                return True
        name = basename(path)
        for p in klass.include_names:
            if fnmatch(name, p):
                return True

    @classmethod
    def ignored(klass, path):
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

    sysdirs = (
            '/usr/share/cllct',
            '/var/lib/cllct',
            '/etc/cllct',
            '*/.cllct',
            '*/.volume',
        )

    ignore_names = (
            '._*',
            '.metadata',
            '.conf',
            'RECYCLER',
            '.TemporaryItems',
            '.Trash*',
            'cllct',
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
    def issysdir( klass, path ):
        path = path.rstrip( os.sep )
        for p in klass.sysdirs:
            if fnmatch( path, p ):
                return True

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

    walk_opts = Values(dict(
        interactive=False,
        recurse=False,
        max_depth=-1,
        include_root=False,
        filters=(None, None),
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
        XXX: could, but does not, yield INode subtype instances.
        """
        if not isinstance(opts, Values):
            opts_ = Values(Klass.walk_opts)
            opts_.update(opts)
            opts = opts_
        else:
            opts = Values(opts.copy())
        # FIXME: validate/process opts or put filter somewhere
        if opts.max_depth > 0:
            assert opts.recurse
        exclusive( opts, 'dirs files symlinks links pipes blockdevs' )
        dirpath = None
        file_filters, dir_filters = filters
        assert os.path.isdir( path )
        if opts.dirs and opts.include_root:
            yield unicode( path, 'utf-8' )
        for root, dirs, files in os.walk(path): # XXX; does not use StatCache
            for node in list(dirs):
                if not opts.recurse and not opts.interactive:
                    dirs.remove(node)
                if not opts.dirs:
                    continue
                dirpath = join(root, node)
# FIXME: like ignored, find better filter?
                if dir_filters:
                    brk = False
                    for fltr in dir_filters:
                        if not fltr(dirpath):
                            dirs.remove(node)
                            brk = True
                            break
                    if brk:
                        continue
                depth = pathdepth(dirpath.replace(path, ''))
                if not StatCache.exists(dirpath):
                #if not os.path.exists(dirpath):
                    log.err("Error: reported non existant node %s", dirpath)
                    if opts.exists != None and opts.exists:
                        if node in dirs:
                            dirs.remove(node)
                        continue 
                elif Klass.ignored(dirpath):
                    log.info("Ignored directory %r", dirpath)
                    dirs.remove(node)
                    continue
                elif opts.max_depth != -1 and depth >= opts.max_depth:
                    dirs.remove(node)
                    continue
                elif opts.interactive:
                    log.note("Interactive walk: %s", dirpath)
                    if not Klass.prompt_recurse(opts):
                        dirs.remove(node)
                dirpath = Klass.decode_path(dirpath, opts)
                yield dirpath
            for leaf in list(files):
                filepath = join(root, leaf)
                if file_filters:
                    brk = False
                    for fltr in file_filters:
                        if not fltr(filepath):
                            files.remove(leaf)
                            brk = True
                            break
                    if brk:
                        continue
                if not StatCache.exists(filepath):
                    log.warn("Error: non existant leaf %s", filepath)
                    if opts.exists != None and not opts.exists:
                        if opts.files:
                            yield filepath
                    continue
                if StatCache.issymlink(filepath) and not opts.symlink:#or not StatCache.isfile(filepath):
                    log.note("Ignored non-regular file %r", filepath)
                    continue
                if File.ignored(filepath):
                    log.info("Ignored file %r", filepath)
                    continue
                if not opts.files: # XXX other types
                    continue
                filepath = Klass.decode_path(filepath, opts)
                yield filepath
       
    @classmethod
    def tree( Klass, path, opts ):
# XXX: what to do with complete attribute list etc? 
        """
        XXX ITreeNode tree can be lazy inited from one node, when traversed with
        a tree-visitor/cloner..
        XXX a list of paths is given with walk, where each path is represented by string
        XXX a tree can be given by loading everything into objetcts and linking this

        TODO return ITreeNode impl, can do lazy walk--but walk will not return INode=types
        """
        p = os.path.basename( path ) + ( os.path.isdir( path ) and os.sep or '' ) 
        INodeType = INode.getsubclass( path )
        node = INodeType( p )
        print path, INodeType, node
        return node

    @classmethod
    def find_newer(Klass, path, path_or_time):
        if StatCache.exists(path_or_time):
            path_or_time = StatCache.getmtime(path_or_time)
        def _isupdated(path):
            return StatCache.getmtime(path) > path_or_time
        for path in clss.walk(path, filters=[_isupdated]):
            yield path

    @classmethod
    def find_newer(Klass, path, path_or_time):
        if StatCache.exists( path_or_time ):
            path_or_time = StatCache.getmtime(path_or_time)
        def _isupdated(path):
            return StatCache.getmtime(path) > path_or_time
        for path in clss.walk(path, filters=[_isupdated]):
            yield path

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


class StatCache:
    """
    Static storage for stat results. 
    XXX: It is up to caller to maintain cache.
    XXX: should fully canonize paths for each INode, ie. clean notation, resolve
        symlinked parent dirs.
    """
    path_stats = {}
    @classmethod
    def init( clss, path ):
        """
        Get stat object and cache, return path.
        """
        if isinstance( path, unicode ):
            path = path.encode( 'utf-8' )
        # canonize path
        p = path
        if path in clss.path_stats:
            v = clss.path_stats[ path ]
            if isinstance( v, str ): # shortcut to dirpath (w/ trailing sep)
                p = v
                v = clss.path_stats[ p ]
        else:    
            v = os.lstat( path )
            if stat.S_ISDIR( v.st_mode ):
                # store shortcut to normalized path
                if path[ -1 ] != os.sep:
                    p = path + os.sep
                    clss.path_stats[ path ] = p
                else:
                    p = path
                    clss.path_stats[ path.rstrip( os.sep ) ] = path
            assert isinstance( path, str )
            clss.path_stats[ p ] = v
        assert isinstance( p, str )
        return p.decode( 'utf-8' )
    @classmethod
    def exists( clss, path ):
        try:
            p = clss.init( path )
        except:
            return
        return True

    """
    st_mode
    st_ino
    st_dev
    st_nlink
    st_uid
    st_gid
    st_size
    st_atime
    st_mtime
    st_ctime
    """
    @classmethod
    def getinode( clss, path ):
        p = clss.init( path ).encode( 'utf-8' )
        return clss.path_stats[ p ].st_ino
    @classmethod
    def getsize( clss, path ):
        p = clss.init( path ).encode( 'utf-8' )
        return clss.path_stats[ p ].st_size
    @classmethod
    def getmtime( clss, path ):
        p = clss.init( path ).encode( 'utf-8' )
        return clss.path_stats[ p ].st_mtime

    modes = {
            'isdir': 'S_ISDIR',
            'ischardev': 'S_ISCHR',
            'isblkdev': 'S_ISBLK',
            'isfile': 'S_ISREG',
            'isfifo': 'S_ISFIFO',
            'issymlink': 'S_ISLNK',
            'issocket': 'S_ISSOCK'
        }

    @classmethod
    def ismode( Klass, path, mode ):
        p = Klass.init( path ).encode( 'utf-8' )
        modefunc = getattr(stat, Klass.modes[ mode ] )
        return modefunc( Klass.path_stats[ p ].st_mode )

    @classmethod
    def getnodetype( Klass, path ):
        p = Klass.init( path ).encode( 'utf-8' )
        for x in Klass.modes:
            modefunc = getattr(stat, Klass.modes[ x ] )
            if modefunc( Klass.path_stats[ p ].st_mode ):
                return x[2:]

    @classmethod
    def isdir( Klass, path ):
        return Klass.ismode( path, 'isdir' )
    @classmethod
    def ischrdev( Klass, path ):
        return Klass.ismode( path, 'ischrdev' )
    @classmethod
    def isblkdev( Klass, path ):
        return Klass.ismode( path, 'isblkdev' )
    @classmethod
    def isfile( Klass, path ):
        return Klass.ismode( path, 'isfile' )
    @classmethod
    def isfifo( Klass, path ):
        return Klass.ismode( path, 'isfifo' )
    @classmethod
    def issymlink( Klass, path ):
        return Klass.ismode( path, 'issymlink' )
    @classmethod
    def issocket( Klass, path ):
        return Klass.ismode( path, 'issocket' )

