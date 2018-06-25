import os


def read_unix(path):
    """
    Return true lines, dropping comments and whitespace lines.
    """
    r = []
    for l in open(path).readlines():
        if l.strip().startswith('#') or not l.strip():
            continue
        r.append(l.rstrip()) # leave indent
    return r

def read_idfile(path):
    """
    Return ID part and optional title part.
    """
    if not os.path.exists(path):
        raise Exception("UNID file missing %s" % path)
    idlines = read_unix(path)
    if not idlines:
        raise Exception("UNID missing in %s" % path)
    if len(idlines) > 1:
        raise Exception("Extraneous content in UNID file %s" % path)
    unid, title = idlines[0], None
    index = unid.find(' ')
    if index:
        unid, title = unid[:index], unid[index+1:]
    return unid, title

def hr(bytes_):
    bytes_ = float(bytes_)
    if bytes_ >= 1099511627776:
        terabytes = bytes_ / 1099511627776
        size = '%.2fT' % terabytes
    elif bytes_ >= 1073741824:
        gigabytes = bytes_ / 1073741824
        size = '%.2fG' % gigabytes
    elif bytes_ >= 1048576:
        megabytes = bytes_ / 1048576
        size = '%.2fM' % megabytes
    elif bytes_ >= 1024:
        kilobytes = bytes_ / 1024
        size = '%.2fK' % kilobytes
    else:
        size = '%.2fb' % bytes_
    return size

humanreadable = lambda s:[(s % 1024**i and "%.1f"%(s/1024.0**i) or \
    str(s/1024**i))+x.strip() for i,x in enumerate(' KMGTPEZY') if s<1024**(i+1) \
    or i==8][0]
