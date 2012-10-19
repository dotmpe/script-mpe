import base64
import os
import time

import lib


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
    """
    return time.strftime(ISO_8601_DATETIME, time_tuple)

def last_modified_header(filepath):
    ltime_tuple = time.gmtime(os.path.getmtime(filepath))
    return iso8601_datetime_format(ltime_tuple)



