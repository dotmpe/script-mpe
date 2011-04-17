#!/usr/bin/python
"""
2011-04-16
    What stdlib can parse DTD's? No mention in O'Reilly nutshell 1st ed.
    Hacking regex parser.
"""
#import xml.sax
#from xml.sax.handler import DTDHandler, ContentHandler
#handler = DTDHandler()
#handler = ContentHandler()
#print xml.sax.parse(source, handler)

#parser = xml.sax.make_parser()
#print parser.parse(source)


#import sgmllib
#parser = sgmllib.SGMLParser()
#parser.feed(source.read())
#print parser.close()

import os, sys, re


EN = re.compile('^..ENTITY +% +(\S+)\s+([^>]+).$', re.M)
EL = re.compile('^..ELEMENT +(\S+) +([^>]+).', re.M)
WS = re.compile('\s+')
collapse_ws = lambda s: WS.sub(' ', s)

EN_REF = re.compile('^%([^;]+);$')
CLSS_REF = re.compile('^[a-z\.]+$')
GROUP = re.compile('^\((.+)\)$')
SEQ = re.compile('[,|]')
MULTIPLE = re.compile('^.*\+$')
MAYBE_ONE = re.compile('^.*\?$')
MORE = re.compile('^.*\*$')

nodes = {'EMPTY':'EMPTY','#PCDATA':'PCDATA'}

groupcnt = 0

def newgroup(spec=None):
    global groupcnt
    group = 'group_' + str(groupcnt)
    nodes[group] = spec
    if spec:
        for subnode in resolve(spec):
            print '\t' + group, '->', subnode

    groupcnt += 1
    return group

def print_seq(node, group):
    seq = None
    for g in group:
        if isinstance(g, str):
            if '|' in g:
                seq = 'or'
                print "%s[label=\"%s\"]" % (node,seq.upper())
            elif ',' in g:
                seq = 'and'
                print "%s[label=\"%s\"]" % (node,seq.upper())
    for g in group:
        if isinstance(g, list):
            n = newgroup()
            print_seq(n, g)
            print '\t'+ node, '->', n
        elif seq == 'and':
            for sub in g.split(','):
                sub = sub.strip()
                if not sub:
                    continue
                for s in resolve(sub):
                    print '\t'+ node, '->', s
        elif seq == 'or':
            for sub in g.split('|'):
                sub = sub.strip()
                if not sub:
                    continue
                for s in resolve(sub):
                    print '\t'+ node, '->', s

def parse_seq(spec, node=None):
    if not node:
        node = newgroup()
    stack = []
    group = ['']
    depth = 0
    while spec:
        c, spec = spec[0], spec[1:]
        if c == '(':
            stack.append(group)
            group.append([''])
            group = group[-1]
            #depth = len(stack)
        elif c == ')':
            group = stack.pop()
        #elif c == ',':
        #    group.append(item)
        #elif c == '|':
        #    group.append(item)
        else:
            group[-1] += c

    print_seq(node, group)
    return node

def resolve(spec):
    global nodecnt
   
    assert spec, "%r"%spec

    if spec in nodes:
        yield nodes[spec]
    elif EN_REF.match(spec):
        #print 'EN_REF', spec
        pass
    #elif CLSS_REF.match(spec):
    #    print 'CLSS_REF', spec
    elif GROUP.match(spec):
        #print 'GROUP', spec
        spec = spec.strip()[1:-1]
        for node in resolve(spec.strip()):
            print "%s[label=\"%s\"]" % (node,'GROUP')
            yield node
    elif MULTIPLE.match(spec):
        pass#print 'MULTIPLE', spec
        n = newgroup(spec.strip()[:-1])
        print "%s[label=\"%s\"]" % (n,'MULTIPLE')
        yield n
    elif MAYBE_ONE.match(spec):
        pass #print 'MAYBE_ONE', spec
        n = newgroup(spec.strip()[:-1])
        print "%s[label=\"%s\"]" % (n,'MAYBE_ONE')
        yield n
    elif MORE.match(spec):
        pass #print 'MORE', spec
        n = newgroup(spec.strip()[:-1])
        print "%s[label=\"%s\"]" % (n,'MORE')
        yield n
    elif SEQ.search(spec):
        #print 'SEQ', spec
        yield parse_seq(spec.strip())
    else:
        assert re.match('[a-z\.]+', spec), spec
        yield spec

def define(name, spec):
    pass#print name

if __name__ == '__main__':

    print """digraph docutils_dtd
{
    rankdir=LR;
    bgcolor=white;color=black;fontcolor=black;
    node[fontname="Bitstream Vera Sans Mono",fontcolor=black];
    edge[fontname="Bitstream Vera Sans Mono",color=red];
    ranksep=1.5;
    """
    source = open('/src/python-docutils/latest/trunk/docutils/docs/ref/docutils.dtd')
    dtd = source.read()
    rs = EN.findall(dtd)
    for name, spec in rs:
        define(name, spec)
    rs = EL.findall(dtd)
    nodecnt = 0
    for node, subclass in rs:
        for subnode in resolve(subclass.strip()):
            print '\t'+ node, '->', subnode

    print """
}
    """

