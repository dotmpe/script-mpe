"""
Read metadata from metafiles.

- Persist composite objects
- Metalink4 <-> HTTPResponseHeaders

- Content-*

"""
import base64
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
            store = shelve.open(dbref)
            PersistedMetaObject.stores[name] = store
        else:
            store = PersistedMetaObject.stores[name]
        return store

    def load(self, name=None):
        store = PersistedMetaObject.get_store(name=name)
        store[self.key()] = self

class ContentID(PersistedMetaObject):
    """
    """

class File(object):

    patterns = (
            '*.git*',
            '*.pyc',
            '*~',
            '*.swp',
        )

    @classmethod
    def ignored(klass, path):
        for p in klass.patterns:
            if fnmatch(path, p):
                return True

class Dir(object):

    patterns = (
            '*.git',
            )

    @classmethod
    def ignored(klass, path):
        for p in klass.patterns:
            if fnmatch(path, p):
                return True

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
    last_modified = time.strftime(ISO_8601_DATETIME, ltime_tuple)
    return last_modified


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
    path = None
    data = {}
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
        ('Digest', md5_content_digest_header),
        ('Digest', sha1_content_digest_header),
        # TODO: Link, Location?
#            'Content-MD5': lib.get_md5sum_sub, 
# not all instances qualify: the spec only covers the message body, which may be
# chunked.
    )
    allow_multiple = ('Digest', 'Link')

    def __init__(self, path=None, data=None):
        if path:
            if path.endswith('.meta'):
                path = path[:-5]
            assert os.path.exists(path), path
            self.path = path
        if data:
            self.data = data

    @property
    def key(self):
        return hashlib.md5(self.path).hexdigest()

    def get_metafile(self):
        return self.path + '.meta'

    def get_meta_hash(self):
        keys = self.data.keys()
        keys.sort()
        rawdata = ";".join(["%s=%r" % (k, self.data[k]) for k in keys])
        digest = hashlib.md5(rawdata).digest()
        return base64.b64encode(digest)

    def needs_update(self):
        if 'X-Last-Modified' not in self.data:
            return True
        # XXX: datestr = self.data['X-Last-Update']
        datestr = self.data['X-Last-Modified']
        mtime_tuple = time.strptime(datestr, ISO_8601_DATETIME)[0:6]
        # XXX: using tuple UTC -> epoc seconds, OK? or is getmtime local.. depends on host
        mtime = calendar.timegm(mtime_tuple)
        return mtime < os.path.getmtime(self.path)
        
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
        return os.path.exists(path)

    @classmethod
    def has_metafile(cls, path):
        return os.path.exists(path + ".meta") 

    @classmethod
    def walk(self, path):
        """
        Walk all files that may have a metafile, and notice any metafile(-like)
        neighbors.
        """
        for root, nodes, leafs in os.walk(path):

            for node in nodes:
                dirpath = os.path.join(root, node)
                if Dir.ignored(dirpath):
                    err("Ignored directory %r", dirpath)
                    nodes.remove(node)

            for leaf in leafs:
                cleaf = os.path.join(root, leaf)
                if not os.path.isfile(cleaf) or os.path.islink(cleaf):
                    err("Ignored non-regular file %r", cleaf)
                    continue
                if File.ignored(cleaf):
                    err("Ignored file %r", cleaf)
                    continue
                if Metafile.is_metafile(cleaf, strict=False):
                    if not Metafile(cleaf).path:
                        err("Metafile without resource file")
                else:
                    #if Metafile.has_metafile(cleaf):
                    #    metafile = Metafile(cleaf)
                    yield cleaf

    # Mutating methods

    def update(self):
        now = datetime.datetime.now()
        envelope = (
                ('X-Meta-Checksum', lambda x: self.get_meta_hash()),
                ('X-Last-Modified', last_modified_header),
                ('X-Last-Update', lambda x: now), # XXX: prolly equals Date?
            )
        for handlers in self.handlers, envelope:
            for header, handler in handlers:

                try:
                    value = handler(self.path)
                except Exception, e:
                    traceback.print_exc()
                    err("%s: %s", header, e)
                    continue

                if header in self.allow_multiple:
                    if header not in self.data:
                        self.data[header] = []
                    elif not isinstance(self.data[header], list):
                        self.data[header] = [ self.data[header] ]
                    self.data[header].append(value)
                else:
                    self.data[header] = value

        length = self.data['Content-Length']
        print self.path
        print '\t', lib.human_readable_bytesize(length, suffix_as_separator=True)

    def write(self):
        fl = open(self.get_metafile(), 'w+')
        now = datetime.datetime.now() # XXX: ctime?
        envelope = {
                'X-Meta-Checksum': self.get_meta_hash(),
                'X-Last-Update': now, # XXX: prolly equals Date?
            }
        for data in self.data, envelope:
            for header in data:
                value = data[header]
                fl.write("%s: %s\r\n" % (header, value))
        fl.close()

    def read(self):
        if not self.has_metafile():
            raise Exception("No metafile exists")
        fl = open(self.get_metafile(), 'r')
        for line in fl.readlines():
            p = line.index(':')
            header = line[:p].trim()
            value = line[p+1:].trim()
            self.data[header] = value
            fl.write("%s: %s" % (header, value))
        fl.close()



