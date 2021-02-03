import os
from os.path import join
from fnmatch import fnmatch
import re
import stat
import time
from datetime import datetime
import base64

import zope.interface
import xattr
import pbPlist

from script_mpe import confparse
from script_mpe import lib
from script_mpe import log
from script_mpe.lib import Prompt
from script_mpe.res import iface, dt


PATH_R = re.compile("[A-Za-z0-9\/\.,\[\]\(\)_-]")


class INode(object):

    """
    Represents an inode on the filesystem.
    """

    zope.interface.implements(iface.Node)

    def __init__(self, path):
        self.path = path

    def getname(self):
        ""
        return os.path.basename( self.path ) + ( StatCache.isdir( self.path ) and os.sep or '' )
    name = property( getname )

    def getid(self):
        ""
        return StatCache.getinode( self.path )
    nodeid = property( getid )

    @classmethod
    def factory( klass, path ):
        """
        Return new INode subclass instance for an existing path.
        """
        Subklass = klass.getsubclass( path )
        return Subklass( path )

    @classmethod
    def getsubclass( klass, path ):
        """
        Use StatCache to get type name for path,
        then iterate sub-classes and return one that implements that name.
        """
        nodetype = StatCache.getnodetype( path )
        assert nodetype, path
        for SubClass in klass.__subclasses__():
            if SubClass.implements == nodetype:
                return SubClass
        assert False, nodetype

    @classmethod
    def decode_path( klass, path, opts ):
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

    @classmethod
    def filter(self, path, *filters):
        "Return true if all filters match, or false if one or more fails. "
        for fltr in filters:
            # TODO ifgenerator
            if not fltr(path):
                return False
        return True

    @classmethod
    def stat(self, path):
        if not isinstance(path, basestring) and hasattr(path, 'path'):
            path = path.path
        st = os.stat(path)
        d = {
                'date_accessed': datetime.fromtimestamp(st.st_atime),
                'date_modified': datetime.fromtimestamp(st.st_mtime),
                'extended_attributes': get_fs_xattr(path),
                'date_metadata_update': None,
                'date_created': None
            }
        if os.uname() in ( 'Linux', 'Darwin' ):
            d['date_metadata_update'] = datetime.fromtimestamp(st.st_ctime)
        elif os.uname() in ( 'Windows', ):
            d['date_created'] = datetime.fromtimestamp(st.st_ctime)
        return d


def get_fs_xattr(fn):
    x = {}
    for attr in xattr.listxattr(fn):
        value = xattr.getxattr(fn, attr)
        if value.startswith('bplist'):
            x[attr] = pbPlist.pbPlist.PBPlist(value)
        else:
            x[attr] = value
    return x


def __register__():
    from zope.component import getGlobalSiteManager
    gsm = getGlobalSiteManager()
    gsm.registerUtility(INode.factory, iface.ILocalNodeService, 'fs')

    # TODO move to res.iface or res
    def getService(node, *args, **kwds):
        if isinstance(node, INode):
            return INode.factory
        else:
            assert False, (node, args, kwds)
    gsm.registerAdapter(getService, [iface.Node], iface.ILocalNodeService)


class File(INode):
    zope.interface.implements(iface.Node, iface.ILeaf)
    implements = 'file'

    ignore_paths = (
            '*/.Trashes*',
            '*/.TemporaryItems*',
            '*/.git',
        )

    ignore_names = (
            '._*',
            '.crdownload',
            '.DS_Store',
            '*.sw[pon]',
            '*.pyc',
            '*~',
            '*.tmp',
            '*.part',
            '*.crdownload',
            '*.incomplete'
        )

    @classmethod
    def ignored(klass, path):
        """
        File.ignored checks names and paths of files with ignore patterns.
        """
        for p in klass.ignore_paths:
            if path is p or fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
            if name is p or fnmatch(name, p):
                return True

    def is_empty(self):
        return os.path.getsize(self.path) < 1


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
    zope.interface.implements(iface.Node, iface.ITree)
    implements = 'dir'

    ignore_paths = File.ignore_paths

    ignore_names = (
            'RECYCLER',
            '.TemporaryItems',
            '.Trash*',
            '.git',
            '.svn',
            '.hg',
            '.bzr',
            '.cache',
            'System Volume Information',
            '*com.docker.docker'
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
            if path is p or fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
            if name is p or fnmatch(name, p):
                return True

    @classmethod
    def prompt_recurse(klass, opts):
        v = Prompt.query("Recurse dir?", ("Yes", "No", "All"))
        if v is 2:
            opts.recurse = True
            return True
        elif v is 0:
            return True
        return False

    @classmethod
    def prompt_ignore(klass, opts):
        v = Prompt.query("Ignore dir?", ["No", "Yes"])
        return v is 1

    @classmethod
    def Check_ignored(klass, filepath, opts):
        #if os.path.islink(filepath) or not os.path.isfile(filepath):
        if os.path.islink(filepath) or ( not os.path.isfile(filepath) and not os.path.isdir(filepath)) :
            log.warn("Ignored non-regular path %r", filepath)
            return True
        elif klass.ignored(filepath) or File.ignored(filepath):
            log.info("Ignored file %r", filepath)
            return True

    @classmethod
    def check_recurse(klass, dirpath, opts):
        #if not opts.recurse and not opts.interactive:
        #    return False
        depth = dirpath.strip('/').count('/')
        if klass.ignored(dirpath):
            log.info("Ignored directory %r", dirpath)
            return False
        elif opts.max_depth != -1 and depth+1 >= opts.max_depth:
            log.info("Ignored directory %r at level %i", dirpath, depth)
            return False
        elif opts.recurse:
            return True
        elif opts.interactive:
            log.info("Interactive walk: %s",dirpath)
            if klass.prompt_recurse(opts):
                return True
            elif klass.prompt_ignore(opts):
                assert False, "TODO: write new ignores to file"

    walk_opts = confparse.Values(dict(
        descend=True, # reverse direction, yield roots and then recurse walk
        interactive=False,
        recurse=False,
        max_depth=-1,
        include_root=False,
        # custom filters:
        exists=None, # 1 , -1 for exclusive exists; or 0 for either
        # None for include, False for exclude, True for exclusive:
        dirs=None,
        files=None,
        symlinks=None,
        links=None,
        pipes=None,
        blockdevs=None,
    ))

    @classmethod
    def get_walk_opts(klass, **kwds):
        opts_ = confparse.Values(klass.walk_opts)
        if kwds: opts_.update(kwds)
        if opts_.max_depth > 0: assert opts_.recurse
        exclusive( opts_, 'dirs files symlinks links pipes blockdevs' )
        return opts_

    @classmethod
    def Walk(klass, path, opts={}, filters=(None,None)):
        """
        Build on os.walk, this goes over all directories and other paths
        non-recursively.
        It returns all full paths according to walk-opts.
        FIXME: could, but does not, yield INode subtype instances.
        XXX: filters, see dev_treemap
        """
        # XXX if not opts.descend:
        #    return self.walkRoot( path, opts=opts, filters=filters )

        assert isinstance(path, basestring), (path, path.__class__)
        opts = klass.get_walk_opts(**opts)
        file_filters, dir_filters = filters

        dirpath = None
        if not os.path.isdir( path ):
            if opts.exists > -1:
                log.err("Cannot walk non-dir path with opt.exists. ")
            elif opts.dirs:
                yield path
        else:
            if opts.dirs and opts.include_root:
                yield unicode( path, 'utf-8' )

            for root, dirs, files in os.walk(path):
                for node in list(dirs):
                    if not opts.recurse: # and not opts.interactive:
                        dirs.remove(node)
                    dirpath = join(root, node)
                    if dir_filters:
                        if not Dir.filter(dirpath, *dir_filters):
                            dirs.remove(node)
                            continue
                    depth = pathdepth(dirpath.replace(path, ''))
                    if not os.path.exists(dirpath):
                        log.err("Error: reported non existant node %s", dirpath)
                        if node in dirs: dirs.remove(node)
                        continue
                    elif klass.Check_ignored(dirpath, opts):
                        log.info("Ignored dir: %s", dirpath)
                        if node in dirs: dirs.remove(node)
                        continue
                    elif not klass.check_recurse(dirpath, opts):
                        if node in dirs:
                            dirs.remove(node)
                    if not opts.dirs:
                        continue
#                    continue # exception to rule excluded == no yield
# caller can sort out wether they want entries to subpaths at this level
                    assert isinstance(dirpath, basestring)
                    dirpath = klass.decode_path(dirpath, opts)
                    if not dirpath: continue
                    assert isinstance(dirpath, unicode)
                    try:
                        dirpath.encode('ascii')
                    except UnicodeDecodeError, e:
                        log.err("Warning: non-ascii dirname %s", dirpath)
                    yield dirpath

                for leaf in list(files):
                    filepath = join(root, leaf)
                    if file_filters:
                        if not File.filter(filepath, *file_filters):
                            log.info("Filtered file %r", filepath)
                            files.remove(leaf)
                            continue
                    if not os.path.exists(filepath):
                        log.err("Error: non existant leaf %s", filepath)
                        if opts.exists != None and not opts.exists:
                            if opts.files:
                                yield filepath
                        else:
                            files.remove(leaf)
                        continue
                    elif klass.Check_ignored(filepath, opts):
                        log.info("Ignored file %r", filepath)
                        files.remove(leaf)
                        continue
                    filepath = klass.decode_path(filepath, opts)
                    if not filepath: continue
                    if not opts.files: # XXX other types
                        continue
                    try:
                        filepath.encode('ascii')
                    except UnicodeDecodeError, e:
                        log.err("Warning: non-ascii filename %s", filepath)
                    yield filepath

    # XXX: made instance entry, but all options (e.g ignores) are static still
    def walk(self, opts={}, filters=(None,None)):
        return self.__class__.Walk(self.path, opts, filters)

    @classmethod
    def walkRoot(klass, path, opts=walk_opts, filters=(None, None)):
        "Walks rootward; dirs only. "
        "Yields dirs rootward along a single path, unless resolve links"
        paths = [path]
        while paths:
            path = paths.pop()
            elements = path.split(os.path.sep)
            isroot = path.startswith(os.path.sep)
            while elements:
                path = os.path.join(*elements)
                if isroot:
                    path = os.sep + path
                if os.path.islink(path):
                    target = os.readlink(path)
                    if not target.startswith(os.sep):
                        target = os.path.join(dirname(path), target)
                    paths.append(target)
                if Dir.filter(path, *filters[0]):
                    yield path
                elements.pop()

    @classmethod
    def tree( klass, path, opts, tree=None ):
# XXX: what to do with complete attribute list etc?
        """
        Given a path name string, uses INode.factory to get an ITree interface to
        the file tree. The tree can be traversed using IHierarchicalVisitor,
        and using an specific IAccepterAdapter for each nodetype, ie. fs.Dir and
        fs.File.

        If used with another ITree and ITreeUpdater this makes an in-memory
        copy of the tree using an specific IAccepterAdapter for fs.Dir and
        fs.File.

        XXX a tree can be given by loading everything into objetcts and linking this
        """
        # first get a transient tree if we need one
        if not iface.ITree.providedBy( tree ):
            tree = iface.ITree( tree )
        # now adapt it to an interface that can walk another tree
        traveler = iface.ITraveler( tree )
        # then get the rootnode for an filesystem ITree
        rootnode = INode.factory( path )
        # and make the traveler walk that ITree, using the IVisitor required.
        visitor = DictNodeUpdater(self)
        traveler.travel( rootnode, visitor )
        return tree

    @classmethod
    def find_newer(klass, path, path_or_time):
        if StatCache.exists(path_or_time):
            path_or_time = StatCache.getmtime(path_or_time)
        def _isupdated(path):
            return StatCache.getmtime(path) > path_or_time
        for path in klass.walk(path, filters=[_isupdated]):
            yield path

    @classmethod
    def find_newer(klass, path, path_or_time):
        if StatCache.exists( path_or_time ):
            path_or_time = StatCache.getmtime(path_or_time)
        def _isupdated(path):
            return StatCache.getmtime(path) > path_or_time
        for path in klass.walk(path, filters=[_isupdated]):
            yield path

    # ITree -
    def get_subnodes(self):
        for name in os.listdir(self.path):
            # XXX yields relative path INode
            p = os.path.join( self.path, name )
            yield INode.factory( p )
    subnodes = property( get_subnodes )
    def append(self, node):
        raise NotImplementedError
    def remove(self, node):
        raise NotImplementedError

    def get_attributes(self):
        return {}
    attributes = property( get_attributes )
    def set_attr(self, name, value):
        raise NotImplementedError
    def get_attr(self, name):
        raise NotImplementedError


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
    TODO: should use inode
    """
    path_stats = {}
    @classmethod
    def init( klass, path ):
        """
        Get stat object and cache, return path.
        """
        if isinstance( path, unicode ):
            path = path.encode( 'utf-8' )
        # canonize path
        p = path
        if path in klass.path_stats:
            v = klass.path_stats[ path ]
            if isinstance( v, str ): # shortcut to dirpath (w/ trailing sep)
                p = v
                v = klass.path_stats[ p ]
        else:
            statv = os.lstat( path )
            if stat.S_ISDIR( statv.st_mode ):
                # store shortcut to normalized path
                if path[ -1 ] != os.sep:
                    p = path + os.sep
                    klass.path_stats[ path ] = p
                else:
                    p = path
                    klass.path_stats[ path.rstrip( os.sep ) ] = path
            assert isinstance( p, str )
            klass.path_stats[ p ] = statv
        assert isinstance( p, str )
        return p.decode( 'utf-8' )
    @classmethod
    def exists( klass, path ):
        try:
            p = klass.init( path )
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
    def getinode( klass, path ):
        p = klass.init( path ).encode( 'utf-8' )
        return klass.path_stats[ p ].st_ino
    @classmethod
    def getsize( klass, path ):
        p = klass.init( path ).encode( 'utf-8' )
        return klass.path_stats[ p ].st_size
    @classmethod
    def getmtime( klass, path ):
        p = klass.init( path ).encode( 'utf-8' )
        return klass.path_stats[ p ].st_mtime

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
    def ismode( klass, path, mode ):
        p = klass.init( path ).encode( 'utf-8' )
        modefunc = getattr(stat, klass.modes[ mode ] )
        return modefunc( klass.path_stats[ p ].st_mode )

    @classmethod
    def getnodetype( klass, path ):
        p = klass.init( path ).encode( 'utf-8' )
        for x in klass.modes:
            modefunc = getattr(stat, klass.modes[ x ] )
            if modefunc( klass.path_stats[ p ].st_mode ):
                # return mode name
                return x[2:]

    @classmethod
    def isdir( klass, path ):
        return klass.ismode( path, 'isdir' )
    @classmethod
    def ischrdev( klass, path ):
        return klass.ismode( path, 'ischrdev' )
    @classmethod
    def isblkdev( klass, path ):
        return klass.ismode( path, 'isblkdev' )
    @classmethod
    def isfile( klass, path ):
        return klass.ismode( path, 'isfile' )
    @classmethod
    def isfifo( klass, path ):
        return klass.ismode( path, 'isfifo' )
    @classmethod
    def issymlink( klass, path ):
        return klass.ismode( path, 'issymlink' )
    @classmethod
    def issocket( klass, path ):
        return klass.ismode( path, 'issocket' )

def md5_content_digest_header(filepath):
    md5_hexdigest = lib.get_md5sum_sub(filepath)
    md5_b64encoded = base64.b64encode(md5_hexdigest.decode('hex'))
    return "MD5=%s" % md5_b64encoded

def sha1_content_digest_header(filepath):
    sha1_hexdigest = lib.get_sha1sum_sub(filepath)
    sha1_b64encoded = base64.b64encode(sha1_hexdigest.decode('hex'))
    return "SHA1=%s" % sha1_b64encoded

def last_modified_header(filepath):
    ltime_tuple = time.gmtime(os.path.getmtime(filepath))
    return dt.iso8601_datetime_format(ltime_tuple)

def basepathparts(path):
    basedir = os.path.dirname(path)
    basename = os.path.basename(path)
    name, extpart = os.path.splitext(basename)
    return basedir, name, extpart

def basepath(path):
    basedir, name, extpart = basepathparts(path)
    return os.path.join(basedir, name)
