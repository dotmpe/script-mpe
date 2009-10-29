#!/usr/bin/env python
"""
Simpler Xu tools.

Print one or more ranges from different source documents, regardless of encoding, format.

Both query and fragment notation read. 
Byterange only.

Eg. the shebang line of this file:

- snip.py?scrow/0.1&locspec=byterange:0/21
- snip.py#scrow/0.1,byterange:0:21 

"""
import os
import os
import sys
import urlparse
import re


PROTO_VERSION = 'scrow/0.1'



if __name__ == '__main__':

    pointers = []

    for range in sys.argv[1:]:
        if range.endswith('.snip'):
            for line in open(range).readlines():
                line = line.strip()
                if not line.startswith('#'):
                    pointers.append(line)
        else:
            pointers.append(range)

    ranges = []
    for range in pointers:
        s, a, p, p2, q, f = urlparse.urlparse(range)
        
        path = p + p2

        q = q.split('&')
        if q and q[0]:
            assert q[0] == PROTO_VERSION
            m = re.match('^locspec=([a-z]*range):([0-9]*)/([0-9]*)$', q[1])
            range = [ int(p) for p in m.groups()[1:3] if p.isalnum() ]
            ranges.append((path, m.group(1)) + tuple(range))
            
        f = f.split(',')
        if f and f[0]:
            assert f[0] == PROTO_VERSION
            m = re.match('^([a-z]*range):([0-9]*)/([0-9]*)$', f[1])
            range = [ int(p) for p in m.groups()[1:3] if p.isalnum() ]
            ranges.append((path, m.group(1)) + tuple(range))

    fd = {}
    for path, rtype, offset, length in ranges:
        if path in fd:
            fl = fd[path]
        else:
            fl = fd[path] = open(path)

        assert rtype == 'byterange'

        if not offset:
            offset = 0
        if not length:
            offset = os.path.getsize(path)

        fl.seek(offset)
        print fl.read(length)

    for fn in fd:
        fd[fn].close()
