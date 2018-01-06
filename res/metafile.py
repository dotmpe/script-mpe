import base64
import datetime
import os
from os.path import isdir
import hashlib
import socket
import time
import traceback
import uuid
from glob import glob
from fnmatch import fnmatch

import calendar

from script_mpe import lib, log, confparse
from script_mpe.res import fs

from .persistence import PersistedMetaObject



class MetaProperty(object):

    """
    Facade to tie volume/path/prop to its impl.
    """

    cname = ''
    depends = ()
    provides = ()

    def __init__(self, metaresolver):
        self.resolver = metaresolver
    def extract(self, props, path, opts):
        pass
    def applies(self, props, path, opts):
        return 0
    def __get__(self, obj, type=None):
        print 'MP get', obj, type
    def __set__(self, obj, value):
        print 'MP set', obj, value
    def __delete__(self, obj):
        print 'MP delete', obj

# MP may test for extraction and fail
# MP may be extractor and/or provide classnames for (possible) extractors
class MetaContentLocationProperty(MetaProperty):

    cname = 'rsr:content-location'
    depends = ()

    def applies(self, props, path, opts):
        if os.path.exists(path): # and has read access
            return 1
    def extract(self, props, path, opts):
        # XXX get global id from meta or volume.
        hostname = socket.gethostname()
        return "rsr://%s%s#%s" % (hostname, self.resolver.meta.volume.path, path)
class MetaContentLengthProperty(MetaProperty):
    cname = 'rsr:content-length'
    depends = 'rsr:content-location',
    def extract(self, props, path, opts):
        if os.path.isfile(path):
            return os.path.getsize(path)
class MetaContentSHA1DigestProperty(MetaProperty):
    cname = 'rsr:content-sha1-digest'
    depends = 'rsr:content-location',
    def extract(self, props, path, opts):
        if os.path.isfile(path):
            return lib.get_sha1sum_sub(path)
class MetaContentTypeProperty(MetaProperty):
    cname = 'rsr:content-type'
    depends = 'rsr:content-id',
    provides = 'subclass-exclusive',
    def extract(self, props, path, opts):
        return lib.get_mediatype_sub(path)
class MetaContentSparseChecksumProperty(MetaProperty):
    cname = 'rsr:content-sparse-checksum'
    depends = 'rsr:content-location',
    def extract(self, props, path, opts):
        if os.path.isfile(path):
            return
class MetaContentIDProperty(MetaProperty):
    cname = 'rsr:content-id'
    depends = 'rsr:content-sha1-digest',

class MetaContentApplicationTypeProperty(MetaContentTypeProperty):
    version = 0.1
    depends = ()
    provides = 'subclasses'

class MetaContentAudioTypeProperty(MetaContentTypeProperty):
    version = 0.1
class MetaContentImageTypeProperty(MetaContentTypeProperty):
    version = 0.1
class MetaContentVideoTypeProperty(MetaContentTypeProperty):
    version = 0.1
class MetaContentTextTypeProperty(MetaContentTypeProperty):
    version = 0.1

class VideoDurationMetaProperty(MetaContentVideoTypeProperty):
    cname = 'rsr:video-duration'

class CharacterCountMetaProperty(MetaContentTextTypeProperty):
    cname = 'rsr:character-count'
class WordCountMetaProperty(MetaContentTextTypeProperty):
    cname = 'rsr:word-count'

_reg = {}
def mp_dependency(mp_class, mp_class_require):
    if mp_class.cname not in _reg:
        _reg[mp_class.cname] = mp_class
    if mp_class_require.cname not in _reg:
        _reg[mp_class_require.cname] = mp_class_require
    if mp_class.cname not in mp_class_require.provides:
        mp_class_require.provides = mp_class_require.provides + (mp_class.cname,)
    if mp_class_require.cname not in mp_class.depends:
        mp_class.depends = mp_class.depends + ( mp_class_require.cname , )
mp_dependency(MetaContentLengthProperty, MetaContentLocationProperty)
mp_dependency(MetaContentSHA1DigestProperty, MetaContentLocationProperty)
mp_dependency(MetaContentIDProperty, MetaContentSHA1DigestProperty)
mp_dependency(MetaContentTypeProperty, MetaContentLocationProperty)
mp_dependency(MetaContentSparseChecksumProperty, MetaContentLocationProperty)

# Unit test
assert MetaContentLocationProperty.depends == (), MetaContentLocationProperty.depends
assert MetaContentIDProperty.depends == ( MetaContentSHA1DigestProperty.cname, ), MetaContentIDProperty.depends
assert MetaContentSHA1DigestProperty.depends == ( MetaContentLocationProperty.cname,), MetaContentSHA1DigestProperty.depends
#

def mpe_prerequisites(mp_class):
    for cname in mp_class.depends:
        yield _reg[cname]
#
class MetaResolver(object):

    """
    Adapt metafile content
    """

    default_props = (
#                'MetaContentIDProperty',
                MetaContentTypeProperty,
    #            'MetaContentMD5DigestProperty',
    #            'MetaContentSHA1DigestProperty',
    #            'MetaContentLengthProperty'
            )

    def __init__(self, meta, data={}):
        self.meta = meta
        self.data = data
        self.extractors = {}

    def load(self):
        "Read X-Meta-Feature header. "
        spec = self.data.get('rsr:meta-features', '')
        if not spec:
            return
        specs = [ s.strip().split('=') for s in spec.split(';') if s.trim() ]
        print 'TODO load MP\'s from spec', specs

    def list(self):
        "List current meta properties. "
        print 'MetaResolver.list', self.data.keys()

    def persist(self):
        "Write X-Meta-Feature header. "
        spec = ";".join([ "=".join(k, v) for k, v in self.data.items() ])
        self.data['rsr:meta-features'] = spec

    def run(self, mp_class, path, opts):
        mp = mp_class(self)
#        self.props[mp.cname] = mp.applies(self.data, path, opts)
#        if self.propstat[mp.cname] == 0:
#            return
        try:
            self.data[mp.cname] = mp.extract(self.data, path, opts)
        except Exception, e:
            log.err('Failed getting %s for %s: %s', mp.cname, path, e)

    def discover(self, path, opts):
        """
        todo get current MP from XMetaFeatures
            - fetch metalink or read mff
        """
        props = list(self.default_props)
        p = 0
        while len(props) > p:
            mp_class = props[p]
            for mp_dep_class in mpe_prerequisites(mp_class):
                # prepend all prerequisite MP classes before current
                if mp_dep_class not in props:
                    props.insert(p, mp_dep_class)
            if mp_class != props[p]:
                continue # start over, proc prerequisite MP classes first
            # fetch value from MP classj
            self.run(mp_class, path, opts)
            if 'subclass-exclusive' in mp_class.provides:
                # append one from subclasses based on value from current MP class
                pass#print mp_class, mp_class.__subclasses__()
            if 'subclasses' in mp_class.provides:
                # append all subclasses as dependencies
                pass#print mp_class, mp_class.__subclasses__()
            p += 1

def meta_property(name, klass):
    pass

class SHA1Sum(object):
    checksums = None
    def __init__(self):
        self.checksums = {}
    def parse_data(self, lines):
        for line in lines:
            p = line.find(' ')
            checksum, filepath = line[:p].strip(), line[p+1:].strip()
            self.checksums[checksum] = filepath
    def __iter__(self):
        return iter(self.checksums)
    def __getitem__(self, checksum):
        return self.checksums[checksum]


class Metafile(PersistedMetaObject):

    """
    TODO: Abstraction for local filesystem paths in a Metadir.
    Use context (metadir) to resolve and track metadata.

    FIXME make this as a hub for shelve/file instances. Autodiscover, do a few
    methods of storage and see what works.

    Metafile exists as a file <file>.extension along a regular file.
    Some dotnames could be considered directory metafiles.

    TODO the metafile data is stored alternatively in the shelve from a metadir.
        this implements a (database0 PersistedMetaObject, see MetafileFile for
        th other..
    """
    storage_name = 'metafile'

    sha1sum = meta_property('sha1sum', SHA1Sum)

    def __init__(self, path, storage=None, context=None, auto_populate=True):
        #if not issubclass(type(path), INode):
        if isinstance(path, basestring):
            path = fs.INode.factory(path)
        self.path = path
        if not context:
            context = Metadir(os.path.dirname(path.path))
        self.context = context
        #if not storage:
        #    storage = self.__class__.storage_name
        #self.store = PersistedMetaObject.get_store(name=storage)
        if auto_populate:
            self.context.resolve(self, 'path')



class MetafileFile(object): # XXX: Metalink syntax

    """
    A MIME-headers like file, exists as a snapshot of a certain graph state.

    Headers for the resource entity in the file.

    XXX: This is obviously the same as metalink format, and should learn from
        that. Metalink has also been expressed as HTTP headers, though the
        proposed standard [RFC 5854] specifies XML formatting.
    """
    default_extension = '.meta'
    related_extensions = [
        '.meta4',
        '.metalink',
        '.torrent',
        '.md5sum',
        '.sha1sum',
        '.lnk',
        '.uriref',
    ]
    handlers = (
#            'X-Content-Label': lib.get_format_description_sub,
        ('X-Content-Description', lib.get_format_description_sub),
        ('Content-Type', lib.get_mediatype_sub),
        ('Content-Length', os.path.getsize),
        #('Digest', fs.md5_content_digest_header),
        ('Digest', fs.sha1_content_digest_header),
        # TODO: Link, Location?
#            'Content-MD5': lib.get_md5sum_sub,
# not all instances qualify: the spec only covers the message body, which may be
# chunked.
    )
    allow_multiple = ('Link',) #'Digest',)

    def __init__(self, path=None, data={}, update=False):
        self.path = None
        self.basedir = None
        if path:
            self.set_path(path)
        self.data = data
        if self.__class__.has_metafile(self.path, self.basedir):
            self.read()
        #if self.path:
        #    if self.has_metafile():
        #        if update and self.needs_update():
        #            self.update()

    def __str__(self):
        return "[Meta:%s %s]" % (self.path, self.non_zero())

    def set_path(self, path):
        if path.endswith('.meta'):
            path = path[:-5]
        #assert os.path.exists(path), path
        self.path = path

    @property
    def key(self):
        return hashlib.md5(self.path).hexdigest()

    @classmethod
    def get_metafile(Class, path, basedir=None):
        if not basedir:
            return path + '.meta'
        else:
            assert os.path.isdir('.cllct')
            assert os.path.isdir('media/content')
            return basedir + path + '.meta'

    def non_zero(self):
        return self.__class__.has_metafile(self.path, self.basedir) \
                and os.path.getsize(self.__class__.get_metafile(self.path, self.basedir)) > 0

    def get_meta_hash(self):
        keys = self.data.keys()
        keys.sort()
        for k in ('X-Meta-Checksum', 'X-Last-Update', 'Location'):
            if k in keys:
                del keys[keys.index(k)]
        rawdata = ";".join(["%s=%r" % (k, self.data[k]) for k in keys])
        digest = hashlib.md5(rawdata).digest()
        return base64.b64encode(digest)

    @property
    def mtime(self):
        # XXX: using tuple UTC -> epoc seconds, OK? or is getmtime local.. depends on host
        if 'X-Last-Modified' in self.data:
            datestr = self.data['X-Last-Modified']
            return calendar.timegm( time.strptime(datestr,
                dt.ISO_8601_DATETIME)[0:6])

    @property
    def utime(self):
        if 'X-Last-Update' in self.data:
            datestr = self.data['X-Last-Update']
            return calendar.timegm( time.strptime(datestr,
                dt.ISO_8601_DATETIME)[0:6])

    def needs_update(self):
        """
        XXX: This mechanism is very rough. The entire file is rewritten, not just
        updated values.
        """
        needs_update = (
            not self.non_zero(),
            self.mtime < os.path.getmtime( self.path ),
            #self.utime < os.path.getmtime(self.get_metafile()),
            'Digest' not in self.data,
            'X-First-Seen' not in self.data,
            'X-Last-Seen' not in self.data,
            'X-Last-Modified' not in self.data,
            'Content-Length' not in self.data
        )
        if 'Content-Length' in self.data:
            rs, ms = os.path.getsize(self.path), int(self.data['Content-Length'])
            needs_update += (rs != ms,)

        # xxx: chatter
        updates = [i for i in needs_update if i]
        attr = ['digest', 'first-seen', 'last-seen', 'last-modified', 'content-length']
        for i1, i2 in enumerate(needs_update):
            if not i2:
                continue
            if i1 == 0:
                print '\tNew Metafile'
            elif i1 == 1:
                print '\tUpdated file'
            elif i1 == 7:
                print '\tFile changed size'
            else:
                print '\tNew attribute', attr[i1-2]
        # /xxx:chatter

        needs_update = updates != []
        if needs_update:
            print "\t",len(updates), 'updates'
            return needs_update

    #
    @classmethod
    def is_metafile(cls, path, strict=True):
        ext = cls.default_extension
        if strict:
            return path.endswith(ext)
        else:
            # XXX: not implemented
            exts = [ext] + Metafile.related_extensions
            for suffix in exts:
                if path.endswith(suffix):
                    return True

    def exists(self):
        #if self.data:# and self.non_zero():
        #    self.data['X-Last-Seen'] = dt.iso8601_datetime_format(now.timetuple())
        return self.__class__.has_metafile(self.path, self.basedir)

    @classmethod
    def has_metafile(Class, path, basedir=None):
        return os.path.exists(Class.get_metafile(path, basedir))

    @classmethod
    def find(klass, path, shelve=None):
        assert not shelve, 'TODO'
        metafile = Metafile.fetch(pathid)
        metafile = Metafile(path)
        metafile.fetch()

    @classmethod
    def walk(self, path, max_depth=-1):
        # XXX: maybe rewrite to Dir.walk
        """
        Walk all files that may have a metafile, and notice any metafile(-like)
        neighbors?
        """
        for root, nodes, leafs in os.walk(path):
            for node in list(nodes):
                dirpath = os.path.join(root, node)
                if not os.path.exists(dirpath):
                    log.err("Error: reported non existant node %s", dirpath)
                    nodes.remove(node)
                    continue
                depth = dirpath.replace(path,'').strip('/').count('/')
                if fs.Dir.ignored(dirpath):
                    log.warn("Ignored directory %r", dirpath)
                    nodes.remove(node)
                elif max_depth != -1:
                    if depth >= max_depth:
                        nodes.remove(node)
            for leaf in leafs:
                cleaf = os.path.join(root, leaf)
                if not os.path.exists(dirpath):
                    log.err("Error: non existant leaf %s", cleaf)
                    continue
                if not os.path.isfile(cleaf) or os.path.islink(cleaf):
                    #log.warn("Ignored non-regular file %r", cleaf)
                    continue
                if fs.File.ignored(cleaf):
                    #log.warn("Ignored file %r", cleaf)
                    continue
                if Metafile.is_metafile(cleaf, strict=False):
                    if not Metafile(cleaf).path:
                        log.err("Metafile without resource file")
                else:
                    yield cleaf

    # Mutating methods

    def update(self):
        now = datetime.datetime.now()
        if 'X-First-Seen' not in self.data:
            self.data['X-First-Seen'] = dt.iso8601_datetime_format(now.timetuple())
        envelope = (
                #('X-Meta-Checksum', lambda x: self.get_meta_hash()),
                ('X-Last-Modified', fs.last_modified_header),
                ('X-Last-Update', lambda x: dt.iso8601_datetime_format(now.timetuple())),
                ('X-Last-Seen', lambda x: dt.iso8601_datetime_format(now.timetuple())),
            )
        for handlers in self.handlers, envelope:
            for header, handler in handlers:

                value = None

                try:
                    value = handler(self.path)
                except Exception, e:
                    traceback.print_exc()
                    log.err("%s: %s", header, e)
                    continue

                #print header, value
                if header in self.allow_multiple:
                    if header not in self.data:
                        self.data[header] = []
                    elif not isinstance(self.data[header], list):
                        self.data[header] = [ self.data[header] ]

                    self.data[header].append(value)
                else:
                    self.data[header] = value

    def write(self):
        fl = open(self.__class__.get_metafile(self.path, self.basedir), 'w+')
        now = datetime.datetime.now() # XXX: ctime?
        envelope = {
                'X-Meta-Checksum': self.get_meta_hash(),
                'X-Last-Update': dt.iso8601_datetime_format(now.timetuple()),
                'Location': self.path,
            }
        for key in envelope.keys():
            if key in self.data:
                del self.data[key]
        for data in self.data, envelope:
            for header in data:
                value = data[header]
                if isinstance(value, list):
                    value = ", ".join(value)
                fl.write("%s: %s\r\n" % (header, value))
        fl.close()
        mtime = calendar.timegm( now.timetuple() )#[:6] )
        os.utime(self.__class_.get_metafile(self.path, self.basedir), (mtime, mtime))

    def read(self):
        if not self.__class__.has_metafile(self.path, self.basedir):
            raise Exception("No metafile exists")
        fl = open(self.__class__.get_metafile(self.path, self.basedir), 'r')
        for line in fl.readlines():
            p = line.index(':')
            header = line[:p].strip()
            value = line[p+1:].strip()
            self.data[header] = value
            #fl.write("%s: %s" % (header, value))
        fl.close()

    def get_sha1sum(self):
        if 'Digest' in self.data:
            data = self.data['Digest']
            if data.startswith('SHA1'):
                b64_sha1 = data[5:]
                return base64.b64decode(b64_sha1).encode('hex')


class Metadir(object):

    """
    Find like metafile, except this checks if a dotname is a dot-directory,
    and if some ID file exists in there.
    """

    # XXX used as class variuables..
    DOTNAME = 'meta'
    DOTID = 'dir'

    NAME_PREFIXES = confparse.name_prefixes
    NAME_SUFFIXES = ['.id', '.uuid']

    @classmethod
    def find_id(klass, *paths):
        prefixes = klass.NAME_PREFIXES + ( '.'+klass.DOTNAME+'/', )
        return list(confparse.find_config_path(klass.DOTID,
            paths=list(paths),
            prefixes=prefixes,
            suffixes=klass.NAME_SUFFIXES,
            filesonly=True
        ))

    @classmethod
    def find_meta(klass, *paths):
        return list(confparse.find_config_path(klass.DOTNAME,
            paths=list(paths),
            prefixes=klass.NAME_PREFIXES,
            suffixes=[''],
            filesonly=True
        ))

    @classmethod
    def find(klass, *paths):
        raise NotImplementedError

    @classmethod
    def fetch(klass, *paths):
        """
        Find metadir by searching for markerleaf indicated by Class'
        DOTID property, using '.' DOTNAME '/' as one of the name prefixes.

        See confparse.find_config_path. This will be searching for the .id
        extensions.

        Returning Class instance for first path, if any.
        """
        configpaths = list(set(klass.find(*paths)))
        if configpaths:
            if len(configpaths) > 1:
                log.warn('Using first config file %s for %s', klass.DOTID, configpaths)
            return klass(configpaths[0]+'/.'+klass.DOTNAME)

    @classmethod
    def require(klass, *paths):
        o = klass.fetch(*paths)
        if not o:
            raise Exception("No %s" % klass.__name__)
        return o

    def __init__(self, path):
        """
        Like metafile, the path here will be the directory itself,
        if it ends with the metadir and id file it, that is stripped.
        """
        path = os.path.normpath( path )
        dotext = os.path.splitext( os.path.basename( path ))
        if dotext[0] == self.DOTID:
            assert dotext[1] in self.NAME_SUFFIXES
            self.path = os.path.dirname( path )
        else:
            self.path = path
        if self.path.endswith(self.DOTNAME) or self.path.endswith(self.DOTNAME+'/'):
            self.path = os.path.dirname( self.path )
            self.prefix = '.'+self.DOTNAME+'/'
        else:
            self.prefix = None
        assert self.DOTNAME not in self.path.strip('/').split('/'), self.path
        self.init()

    @property
    def full_path(self):
        """Return %s metadir path. """ % lib.cn(self)
        return os.path.join(self.path, '.'+self.DOTNAME)

    def metadirref(self, ext='db', name=None):
        if not name:
            name = self.DOTID
        return os.path.join(self.full_path, '%s.%s' % (name, ext))

    @property
    def id_path(self):
        """Return %s metadir id-file path. """ % lib.cn(self)
        # XXX: perhaps rename DOTID just markerleaf to reflect find_config_path
        return self.metadirref( 'id' )

    @property
    def metadir_id(self):
        #if self.exists():
        #    return open(self.id_path).read().strip()
        return self.__id.lower()

    def exists(self):
        return os.path.exists(self.id_path)

    def init(self, create=False, reset=False, metadir_id=None):
        if self.exists() and not reset:
            assert not metadir_id
            self.__id = open(self.id_path).read().strip()
            if ' ' in self.__id:
                p = self.__id.split(' ')
                self.__id, self.__label = p[:1], " ".join(p[2:])
        elif reset or create:
            if not metadir_id:
                metadir_id = str(uuid.uuid4()).lower()
            assert isinstance(metadir_id, str)
            self.__id = metadir_id
            if not os.path.exists(self.full_path):
                os.mkdir(self.full_path)
            open(self.id_path, 'w+').write(self.__id)
            log.note( "%s Metadir.init %s %s" % (
                lib.cn(self), reset and 'Reset' or 'Created', self.full_path  ))
        else:
            self.__id = metadir_id

    def __str__(self):
        if self.__id:
            return "<Metadir:%s at %s, Id %r>" % ( lib.cn(self), self.id_path, self.__id )
        else:
            return "<Metadir:%s at %s, unregistered>" % ( lib.cn(self), self.id_path )

    def __repr__(self):
        return self.__str__()


    """ XXX:

        Metadir.item* -> Metafile path
        .path -> fs.INode date_accessed,date_metadata_update,date_modified,x-attr
        .path -> fs.File size
        .size -> Checksums.*,compression, encodings,,  Mediatype
        .mediatype -> MediatypeParameter parameters,charset,format,delsp
        .checksums* -> lookup...
        .compression -> optimize...
        .encodings -> recode...

    """
    resolvers = {
            'path:fs.INode': "fs.INode.stat:date_accessed,date_metadata_update,date_modified,extended_attributes",
            'path:fs.Dir': "fs.Dir.dir_stat:file_count,dir_count",
            #'path:fs.File': "fs.File.data:data",
            #'data:Stream': "Mediatype.detect:mediatype",
            #'data:Stream': "Checksum.calc:checksums",
            #'mediatype:TextFile': "TextFile.content:content",
            #'checksum:Checksum': "Registry.lookup:refs"
        }
    def resolve(self, item, attr):
        "given start attribute, copy or initialize attributes from other types"
        toresolve = []
        for resolver in self.resolvers.keys():
            if resolver.startswith(attr +':'):
                toresolve += [ resolver ]
        for resolver in toresolve:
            src_attr, type_ = resolver.split(':')
            obj = getattr( item, src_attr )
            if not isinstance(obj, get_global_attr(type_)):
                continue
            handler, trgt_spec = self.resolvers[resolver].split(':')
            self._apply_resolver(item, handler, trgt_spec)

    def _apply_resolver(self, obj, handler_spec, trgt_spec):
        data = get_global_attr(handler_spec)(self)
        if ',' in trgt_spec:
            assert isinstance(data, dict)
            for attr in trgt_spec.split(','):
                setattr(obj, attr, data[attr])
        else:
            setattr(obj, trgt_spec, data)

    # IDir, INode
    def neighbours(self, name, extensions_only=True):
        g = "%s.*" % name
        for p in glob(g):
            yield p

    def find_names(self, name, basedir=None):
        g = "%s.*" % name
        # One filename based filter
        file_fltrs = [ lambda name: fnmatch(os.path.basename(name), g) ]
        if basedir: p = os.path.normpath(basedir)
        else: p = self.path
        for p in fs.Dir.walk(p, dict(recurse=True, files=True), (file_fltrs, None)):
            yield p


def get_global_attr(handler_spec):
    path = handler_spec.split('.')
    obj = globals()[path.pop(0)]
    while path:
        obj = getattr(obj, path.pop(0))
    return obj


class Meta(object):

    """
    Adapter for res.Volume to work on metafile indices.
    """

    def __init__(self, volume):
        self.volume = volume
        # init STAGE shelve
        #ref = volume.idxref('STAGE')
        #self.stage = PersistedMetaObject.get_store(name='STAGE', dbref=ref)

    def get_property(self, name, index='STAGE'):
        assert index == 'STAGE'
        return self.stage[path]

    def exists(self, path):
        """
        Return wether some repository data exists.
        """
        if isdir(path):
            return str(path) in self.volume.indices.dirs
        mf = Metafile(path)
        mff = MetafileFile(path)
        if mf.exists() or mff.exists():
            print 'TODO Meta.exists', mf.exists(), mff.exists()
            return True

    def clean(self, path):
        """
        Determine wether there are dirty properties and return False if so.
        """
        print 'TODO Meta.clean', self.volume, path

# XXX: todo operations on stage index
    def add(self, name, prog, opts):
        """
        Start with MP default(s), continue to discover.

        Put data into STAGE index.
        """
        data = {}
        path = self.volume.pathname(name, prog.pwd)
        if not os.path.exists(path):
            log.err("Ignored %s", path)
            return
        if path in self.stage:
            data = self.stage.get(path)
        resolver = MetaResolver(self, data)
        resolver.discover(path, opts)
        print 'todo add', resolver.data

    def update(self, path, opts):
        pass

    def drop(self, path, opts):
        del index[path]

    def commit(self, message=None):
        """
        Write STAGE index to store, update loookup indices.
        """
        volume.store
        volume.indices


if __name__ == '__main__':
    import os
    print Metadir.find(os.getcwd())

    #import shelve
    #path = '/Volumes/archive-7/media/text/US-patent/US2482773.pdf'
    #vdb = PersistedMetaObject.get_store(name='tmp')
    #mf = Metafile.find(path, vdb)


