import os, re

from . import lib


def file_brief_description(fn):
    return lib.cmd("file -bs %r" % fn).strip()

def file_mime_type_darwin(fn):
    out = lib.cmd("file -bI %r" % fn).strip()
    parts = re.split(r'[; ]+', out)
    majmin = parts.pop(0)
    return majmin

def file_mime_type_linux(fn):
    out = lib.cmd("file -bi %r" % fn).strip()
    parts = re.split(r'[; ]+', out)
    majmin = parts.pop(0)
    return majmin

if os.uname()[0] == 'Darwin':
    filemtype = file_mime_type_darwin
else:
    filemtype = file_mime_type_linux
