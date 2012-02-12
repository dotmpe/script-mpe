"""
Read metadata from metafiles.

- Content-*

"""
import os
import rfc822

import lib
from libcmd import err



class Metafile(object):

    """
    Headers for the resource entity in the file.
    XXX: May not be entirely MIME compliant yet.
    """
    path = None
    data = {}
# FIXME: import CaselessDict from htcache or gate?
    handlers = {
            'X-Content-Label': get_format_description_sub,
            'X-Content-Description': get_format_description_sub,
            'Content-Type': get_mediatype_sub,
            'Content-SHA1': get_sha1sum_sub,
            'Content-MD5': get_md5sum_sub,
            'Content-Length': os.path.getsize,
    }
    
    def __init__(self, path=None, data=None):
        if path:
            if path.endswith('.meta'):
                path = path[:-5]
            assert os.path.exists(path), path
            self.path = path
        if data:
            self.data = data

    def get_metafile(self):
        return self.path + '.meta'

    def is_metafile(cls, path):
        return path.endswith('.meta')

    def exists(cls, path):
        return os.path.exists(path)

    def has_metafile(cls, path):
        return os.path.exists(path + ".meta") 

    def update(self):
        for k in self.handlers:
            self.data[k] = self.handlers[k](self.path)
        print lib.human_readable_bytesize(data['content-length'])

    def write(self):
        fl = open(self.get_metafile() 'w+')
        for header in self.data:
            value = self.data[header]
            fl.write("%s: %s" % (header, value))
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


def get_format_description_sub(path):
    format_descr = lib.cmd("file -bs %r", path)
    if not format_descr:
        err("Failed determining format of %r", path)
    else:
        return format_descr.strip()

def get_mediatype_sub(path):
    mediatypespec = lib.cmd("file -bsi %r", path)
    if not mediatypespec:
        err("Failed determining mediatypespec of %r", path)
    else:
        return mediatypespec.strip()

def get_sha1sum_sub(path):
    try:
        return lib.get_sha1sum_sub(path)
    except Exception, e:
        traceback.print_exc()
        err("%s", e)

def get_md5sum_sub(path):
    try:
        return lib.get_md5sum_sub(path)
    except Exception, e:
        traceback.print_exc()
        err("%s", e)



