"""
Read metadata from metafiles.

- Persist composite objects
- Metalink4 <-> HTTPResponseHeaders

- Content-*

"""
import base64
import bsddb
from bsddb import dbshelve
import calendar
import datetime
from fnmatch import fnmatch
import hashlib
import os
import rfc822
import shelve
import time
import traceback

import lib
import confparse
from taxus import get_session
from libcmd import err
from rsrlib.store import UpgradedPickle, Object


ISO_8601_DATETIME = '%Y-%m-%dT%H:%M:%SZ'

class PersistedMetaObject(Object):

    stores = {}
    "list of loaded stores (static) class scope"
    default_store = 'default'
    "name of default store, to customize per type"

    @classmethod
    def get_store(Klass, name=None, dbref=None):
        if not name:
            name = Klass.default_store
        if name not in PersistedMetaObject.stores:
            assert dbref, "store does not exists: %s" % name
            try:
                store = shelve.open(dbref)
            except bsddb.db.DBNoSuchFileError, e:
                assert not e, "cannot open store: %s, %s, %s" %(name, dbref, e)
            PersistedMetaObject.stores[name] = store
        else:
            store = PersistedMetaObject.stores[name]
        return store

    def load(self, name=None):
        store = PersistedMetaObject.get_store(name=name)
        store[self.key()] = self

class File(object):

    ignore_names = (
            '._*',
            '.crdownload',
            '.DS_Store',
            '.swp',
    )

    ignore_paths = (
            '*.pyc',
            '*~',
            '*.part',
            '*.incomplete',
        )

    @classmethod
    def ignored(klass, path):
        for p in klass.ignore_paths:
            if fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
            if fnmatch(name, p):
                return True


class Dir(object):

    ignore_names = (
            '._*',
            'RECYCLER',
            '.TemporaryItems',
            '.Trash*',
            '.cllct',
            'System Volume Information',
            'Desktop',
            'project',
            'sam*bup*',
            '*.bup',
            '.git',
        )

    ignore_paths = (
            '*.git',
        )

    @classmethod
    def ignored(klass, path):
        for p in klass.ignore_paths:
            if fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
            if fnmatch(name, p):
                return True



def md5_content_digest_header(filepath):
    md5_hexdigest = lib.get_md5sum_sub(filepath)
    md5_b64encoded = base64.b64encode(md5_hexdigest.decode('hex'))
    return "MD5=%s" % md5_b64encoded

def sha1_content_digest_header(filepath):
    sha1_hexdigest = lib.get_sha1sum_sub(filepath)
    sha1_b64encoded = base64.b64encode(sha1_hexdigest.decode('hex'))
    return "SHA1=%s" % sha1_b64encoded

def iso8601_datetime_format(time_tuple):
    """
    Format datetime tuple to ISO 8601 format suitable for MIME messages.
    """
    return time.strftime(ISO_8601_DATETIME, time_tuple)

def last_modified_header(filepath):
    ltime_tuple = time.gmtime(os.path.getmtime(filepath))
    return iso8601_datetime_format(ltime_tuple)


class MIMEHeader(PersistedMetaObject):
    headers = None
    def __init__(self):
        super(PersistedMetaObject, self).__init__()
        self.headers = {}
    def parse_data(self, lines):
        key, value = "", ""
        for idx, line in enumerate(lines):
            if not line.strip():
                if value:
                    self.headers[key] = value
                break
            continuation = line[0].isspace()
            if continuation:
                value += line.strip()
            else:
                if value:
                    self.headers[key] = value
                key = line[:p].strip()
                assert key, (idx, line)
                value = line[p+1:].strip()
    #def parse(self, source):
    #    pass
    def write(self, fl):
        if not hasattr(fl, 'write'):
            if not os.path.exists(str(fl)):
                os.mknod(str(fl))
            fl = open(str(fl), 'w+')
        # XXX: writes string only. cannot break maxlength without have knowledge of header
        for key in self.headers.keys():
            value = self.headers[key]
            fl.write("%s: %s\n" % (key, value))
        fl.close()

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

class HTTPHeader(MIMEHeader):
    pass

class HTTPResponse(HTTPHeader):
    pass


class Metafile(PersistedMetaObject): # XXX: Metalink

    """
    Headers for the resource entity in the file.
    XXX: May not be entirely MIME compliant yet.

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
        #('Digest', md5_content_digest_header),
        ('Digest', sha1_content_digest_header),
        # TODO: Link, Location?
#            'Content-MD5': lib.get_md5sum_sub, 
# not all instances qualify: the spec only covers the message body, which may be
# chunked.
    )
    allow_multiple = ('Link',) #'Digest',)
    basedir = None

    def __init__(self, path=None, data={}, update=False):
        self.path = None
        if path:
            self.set_path(path)
        self.data = data
        if self.has_metafile():
            self.read()
        #if self.path:
        #    if self.has_metafile():
        #        if update and self.needs_update():
        #            self.update()

    def set_path(self, path):
        if path.endswith('.meta'):
            path = path[:-5]
        #assert os.path.exists(path), path
        self.path = path

    @property
    def key(self):
        return hashlib.md5(self.path).hexdigest()

    def get_metafile(self):
        if not self.basedir:
            return self.path + '.meta'
        else:
            assert os.path.isdir('.cllct')
            assert os.path.isdir('media/content')
            return self.basedir + self.path + '.meta'

    def non_zero(self):
        return self.has_metafile() \
                and os.path.getsize(self.get_metafile()) > 0

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
                ISO_8601_DATETIME)[0:6])

    @property
    def utime(self):
        if 'X-Last-Update' in self.data:
            datestr = self.data['X-Last-Update']
            return calendar.timegm( time.strptime(datestr,
                ISO_8601_DATETIME)[0:6])

    def needs_update(self):
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
        #print 'needs_update', needs_update
        return max(needs_update)

    #
    @classmethod
    def is_metafile(cls, path, strict=True):
        ext = cls.default_extension
        if strict:
            return path.endswith(ext)
        else:
            exts = [ext] + Metafile.related_extensions
            for suffix in exts:
                if path.endswith(suffix):
                    return True

    @classmethod
    def exists(cls, path):
        if self.data:
            self.data['X-Last-Seen'] = iso8601_datetime_format(now.timetuple())
        return os.path.exists(path)

    #@classmethod
    def has_metafile(self):
        return os.path.exists(self.get_metafile())

    @classmethod
    def walk(self, path, max_depth=-1):
        """
        Walk all files that may have a metafile, and notice any metafile(-like)
        neighbors.
        """
        for root, nodes, leafs in os.walk(path):
            for node in list(nodes):
                dirpath = os.path.join(root, node)
                if not os.path.exists(dirpath):
                    err("Error: reported non existant node %s", dirpath)
                    nodes.remove(node)
                    continue
                depth = dirpath.replace(path,'').strip('/').count('/')
                if Dir.ignored(dirpath):
                    err("Ignored directory %r", dirpath)
                    nodes.remove(node)
                elif max_depth != -1:
                    if depth >= max_depth:
                        nodes.remove(node)
            for leaf in leafs:
                cleaf = os.path.join(root, leaf)
                if not os.path.exists(dirpath):
                    err("Error: non existant leaf %s", cleaf)
                    continue
                if not os.path.isfile(cleaf) or os.path.islink(cleaf):
                    #err("Ignored non-regular file %r", cleaf)
                    continue
                if File.ignored(cleaf):
                    #err("Ignored file %r", cleaf)
                    continue
                if Metafile.is_metafile(cleaf, strict=False):
                    if not Metafile(cleaf).path:
                        err("Metafile without resource file")
                else:
                    yield cleaf

    # Mutating methods

    def update(self):
        now = datetime.datetime.now()
        if 'X-First-Seen' not in self.data:
            self.data['X-First-Seen'] = iso8601_datetime_format(now.timetuple())
        envelope = (
                ('X-Meta-Checksum', lambda x: self.get_meta_hash()),
                ('X-Last-Modified', last_modified_header),
                ('X-Last-Update', lambda x: iso8601_datetime_format(now.timetuple())),
                ('X-Last-Seen', lambda x: iso8601_datetime_format(now.timetuple())),
            )
        for handlers in self.handlers, envelope:
            for header, handler in handlers:
                
                value = None

                try:
                    value = handler(self.path)
                except Exception, e:
                    traceback.print_exc()
                    err("%s: %s", header, e)
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
        fl = open(self.get_metafile(), 'w+')
        now = datetime.datetime.now() # XXX: ctime?
        envelope = {
                'X-Meta-Checksum': self.get_meta_hash(),
                'X-Last-Update': iso8601_datetime_format(now.timetuple()),
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
        os.utime(self.get_metafile(), (mtime, mtime))

    def read(self):
        if not self.has_metafile():
            raise Exception("No metafile exists")
        fl = open(self.get_metafile(), 'r')
        for line in fl.readlines():
            p = line.index(':')
            header = line[:p].strip()
            value = line[p+1:].strip()
            self.data[header] = value
            #fl.write("%s: %s" % (header, value))
        fl.close()


class Workspace(object):

    def __init__(self, path):
        self.name = os.path.basename(path)
        self.path = os.path.dirname(path)

    @property
    def full_path(self):
        return os.path.join(self.path, self.name)

    def __str__(self):
        return "[%s %s %s]" % (self.__class__.__name__, self.path, self.name)


class Volume(Workspace):

    def __str__(self):
        return repr(self)

    def __repr__(self):
        return "<Volume 0x%x at %s>" % (hash(self), self.db)

    @property
    def db(self):
        return os.path.join(self.full_path, 'volume.db')

    @classmethod
    def find(clss, dirpath):
        path = None
        for path in confparse.find_config_path("cllct", dirpath):
            vdb = os.path.join(path, 'volume.db')
            if os.path.exists(vdb):
                break
            else:
                path = None
        if path:
            return Volume(path)


class Repo(object):

    repo_match = (
            ".git",
            ".svn"
        )

    @classmethod
    def is_repo(klass, path):
        for n in klass.repo_match:
            if os.path.exists(os.path.join(path, n)):
                return True

    @classmethod
    def walk(klass, path, bare=False, max_depth=-1):
        """
        Walk all files that may have a metafile, and notice any metafile(-like)
        neighbors.
        """
        assert not bare
        for root, nodes, leafs in os.walk(path):
            for node in list(nodes):
                dirpath = os.path.join(root, node)
                if not os.path.exists(dirpath):
                    err("Error: reported non existant node %s", dirpath)
                    nodes.remove(node)
                    continue
                depth = dirpath.replace(path,'').strip('/').count('/')
                if Dir.ignored(dirpath):
                    err("Ignored directory %r", dirpath)
                    nodes.remove(node)
                    continue
                elif max_depth != -1:
                    if depth >= max_depth:
                        nodes.remove(node)
                        continue
                if klass.is_repo(dirpath):
                    nodes.remove(node)
                    yield dirpath

