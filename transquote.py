#!/usr/bin/env python
"""Search for text and print spanpointers
Use with transquoter.py from the same directory.
"""
import os, sys, re, urllib2
#sys.path.extend(
#    [os.path.expanduser(u) for u in ('~/lib/py/',
#        '~/src/xu/translit/')])
import transquoter
from hashlib import md5


def absolutize(ref, baseref):

    p = ref.find(':')
    if p and ref[p:p+2] == '://':
        return ref # already absolute ref

    if baseref[-1] != '/': # base may be a neighbour
        p = baseref.rfind('/')
        if p:
            baseref = baseref[:p+1]

    if '/' in ref:
        if '..' in ref:
            pass # TODO

        p = ref.rfind('/')
        if p:
            ref = ref[p+1:]

    return baseref + ref



args = sys.argv[1:]
assert args, "Usage: echo 'find str' 'find ..' | %s uri-ref " % args[0]
requri = args.pop(0)

substrs = sys.stdin.read().split('\0')

data = urllib2.urlopen(requri)

info = data.info()
if 'Content-Location' in info:
    requri = absolutize(info['Content-Location'], requri)

datain = data.read()
md5sum = md5(datain).hexdigest()
assert not '?' in requri
print '@prefix : <%s?x-tq/0.1,md5=%s,length=%s#> .' % (requri, md5sum, len(datain))   
print
print ":fragments = ("


text, title = transquoter.resolve(requri)
if text and text[0] == ' ':
    raise Error, text

for find in substrs:
    find = re.sub(r"\s+", " ", find).strip()
    p = text.find(find)
    if p < 0:
        continue
    e = p + len(find)
    assert text[p:e] == find
    print "<#char=%s,%s>" % (p, e)
print ")."
