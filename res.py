"""
Read metadata from metafiles.

- Content-*

"""
import os

import lib
from libcmd import err


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


class Metafile(object):

    """
    Headers for the resource entity in the file.
    XXX: May not be entirely MIME compliant yet.
    """
    path = None
    data = {}
# FIXME: import CaselessDict from htcache or gate?
    handlers = {
            'x-content-description': get_format_description_sub,
            'content-type': get_mediatype_sub,
            'content-sha1': get_sha1sum_sub,
            'content-md5': get_md5sum_sub,
            'content-length': os.path.getsize,
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
        return os.path.exists(path + ".meta") 

    def update(self):
        for k in self.handlers:
            self.data[k] = self.handlers[k](self.path)
        print lib.human_readable_bytesize(data['content-length'])

    # TODO
    def write(self): pass

