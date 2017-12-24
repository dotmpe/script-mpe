import base64
import os
import time
from datetime import datetime

from script_mpe import lib
from script_mpe.confparse import yaml_load, yaml_dump


ISO_8601_DATETIME = '%Y-%m-%dT%H:%M:%SZ'


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

    NOTE: can use use datetime().isoformat() on instances.
    """
    return time.strftime(ISO_8601_DATETIME, time_tuple)

def isodatetime(s):
    """
    Opposite of datetime().isoformat()
    """
    return datetime.strptime(s, ISO_8601_DATETIME)

def last_modified_header(filepath):
    ltime_tuple = time.gmtime(os.path.getmtime(filepath))
    return iso8601_datetime_format(ltime_tuple)

def obj_serialize_datetime_list(l, ctx):
    r = []
    for n, i in enumerate(l):
      r[n] = obj_serialize_datetime(i, ctx)
    return r

def obj_serialize_datetime_dict(o, ctx):
    r = {}
    for k, v in o.items():
      r[k] = obj_serialize_datetime(v, ctx)
    return r

def obj_serialize_datetime(o, ctx):
    if hasattr(o, 'items'):
      return obj_serialize_datetime_dict(o, ctx)
    elif hasattr(o, 'iter'):
      return obj_serialize_datetime_list(o, ctx)
    else:
      if isinstance(o, datetime):
        o = o.strftime(ctx.opts.flags.serialize_datetime)
      return o
