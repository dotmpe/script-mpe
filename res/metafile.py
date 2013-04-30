import base64
import datetime
import os
import hashlib
import time
import traceback

import calendar
import lib
import util
import log
from persistence import PersistedMetaObject
from res import fs, util


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
        #('Digest', util.md5_content_digest_header),
        ('Digest', util.sha1_content_digest_header),
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
                util.ISO_8601_DATETIME)[0:6])

    @property
    def utime(self):
        if 'X-Last-Update' in self.data:
            datestr = self.data['X-Last-Update']
            return calendar.timegm( time.strptime(datestr,
                util.ISO_8601_DATETIME)[0:6])

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
            exts = [ext] + Metafile.related_extensions
            for suffix in exts:
                if path.endswith(suffix):
                    return True

    @classmethod
    def exists(cls, path):
        if self.data:# and self.non_zero():
            self.data['X-Last-Seen'] = util.iso8601_datetime_format(now.timetuple())
        return os.path.exists(path)

    #@classmethod
    def has_metafile(self):
        return os.path.exists(self.get_metafile())

    @classmethod
    def walk(self, path, max_depth=-1):
        # XXX: may rewrite to Dir.walk
        """
        Walk all files that may have a metafile, and notice any metafile(-like)
        neighbors.
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
                    log.err("Ignored directory %r", dirpath)
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
                    #log.err("Ignored non-regular file %r", cleaf)
                    continue
                if fs.File.ignored(cleaf):
                    #log.err("Ignored file %r", cleaf)
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
            self.data['X-First-Seen'] = util.iso8601_datetime_format(now.timetuple())
        envelope = (
                ('X-Meta-Checksum', lambda x: self.get_meta_hash()),
                ('X-Last-Modified', util.last_modified_header),
                ('X-Last-Update', lambda x: util.iso8601_datetime_format(now.timetuple())),
                ('X-Last-Seen', lambda x: util.iso8601_datetime_format(now.timetuple())),
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
        fl = open(self.get_metafile(), 'w+')
        now = datetime.datetime.now() # XXX: ctime?
        envelope = {
                'X-Meta-Checksum': self.get_meta_hash(),
                'X-Last-Update': util.iso8601_datetime_format(now.timetuple()),
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



