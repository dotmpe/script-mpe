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
