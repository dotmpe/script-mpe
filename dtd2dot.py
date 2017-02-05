#!/usr/bin/python
"""
2011-04-16
    What stdlib can parse DTD's? No mention in O'Reilly nutshell 1st ed.
    Hacking regex parser.
2011-04-17
    This is getting too complex and too buggy. Rewrite needed, use separate
    DTDparser.

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
MAYBE = re.compile('^.*\?$')
MORE = re.compile('^.*\*$')

nodes = {'EMPTY':'EMPTY','#PCDATA':'PCDATA'}

groupcnt = 0

def getgroup(spec=None):
    if spec and spec in nodes:
        return nodes[spec]
    global groupcnt
    if spec and re.match('^[A-Za-z_]+$', spec):
        nodes[spec] = spec
        group = spec
    else:
        group = 'group_' + str(groupcnt)
        nodes[spec] = group
        groupcnt += 1
    if spec:
        for subnode in resolve(spec):
            print '\t' + group, '->', subnode
    return group

def print_seq(node, group):
    s = collapse_ws(''.join([g for g in group if isinstance(g, str)]))
    #print 's',(s, group)
    if s and ( '|' not in s and ',' not in s ):
        assert s in nodes, s
        print '\t'+ node, '->', nodes[s], ';'
        return

    seq = 'SEQ'
    for g in group:
        if isinstance(g, str):
            if '|' in g:
                seq = 'or'
            elif ',' in g:
                seq = 'and'
    print "\t%s [label=\"%s\"] ;" % (node,seq.upper())
    #print "\t%s [label=\"%s\"] ;" % (node, ''.join(group))
    #print 'print_seq', group
    for g in group:
        if isinstance(g, list):
            n = getgroup()
            print_seq(n, g)
            print '\t'+ node, '->', n, ';'
        elif seq == 'and':
            pass#print (g,)
            for sub in g.split(','):
                sub = sub.strip()
                if not sub:
                    continue
                for s in resolve(sub):
                    print '\t'+ node, '->', s, ';'
        elif seq == 'or':
            for sub in g.split('|'):
                sub = sub.strip()
                if not sub:
                    continue
                for s in resolve(sub):
                    print '\t'+ node, '->', s, ';'

def parse_seq(spec, node=None):
    if not node:
        node = getgroup()
        nodes[spec] = node
    stack = []
    group = ['']
    depth = 0
    while spec:
        #print 'parse_seq', 'spec', spec, 'stack:', stack
        c, spec = spec[0], spec[1:]
        if c == '(':
            group.append([''])
            stack.append(group)
            group = group[-1]
            #depth = len(stack)
        elif c == ')':
            group = stack.pop()
            if isinstance(group[-1], list):
                group.append('')
        #elif c == ',':
        #    group.append(item)
        #elif c == '|':
        #    group.append(item)
        else:
            group[-1] += c
    #print 'parse_seq', group
    print_seq(node, group)
    return node

def resolve(spec):
    global nodecnt

    assert spec, "%r"%spec

    if spec in nodes:
        yield nodes[spec]
    elif EN_REF.match(spec):
        print >>sys.stderr,"Unresolved entity: %s" % spec
        n = getgroup()
        nodes[spec] = n
        print '\t%s [label="%s"] ;' % (n,spec)
        yield n
        #print 'EN_REF', spec
        pass
    #elif CLSS_REF.match(spec):
    #    print 'CLSS_REF', spec
    elif GROUP.match(spec):
        #print 'GROUP', spec
        spec = spec.strip()[1:-1]
        for node in resolve(spec.strip()):
            #print "\t%s [label=\"%s\"] ;" % (node,'GROUP')
            yield node
    elif MULTIPLE.match(spec):
        pass#print 'MULTIPLE', spec
        n = getgroup(spec.strip()[:-1].strip())
        #print "\t%s [label=\"%s\"] ;" % (n,spec)
        print "\t%s [label=\"%s\"] ;" % (n,'+')
        nodes[spec] = n
        yield n
    elif MAYBE.match(spec):
        pass #print 'MAYBE', spec
        n = getgroup(spec.strip()[:-1].strip())
        #print "\t%s [label=\"%s\"] ;" % (n,spec)
        print "\t%s [label=\"%s\"] ;" % (n,'?')
        nodes[spec] = n
        yield n
    elif MORE.match(spec):
        pass #print 'MORE', spec
        n = getgroup(spec.strip()[:-1].strip())
        #print "\t%s [label=\"%s\"] ;" % (n,spec)
        print "\t%s [label=\"%s\"] ;" % (n,'*')
        nodes[spec] = n
        yield n
    elif SEQ.search(spec):
        #print 'SEQ', spec
        yield parse_seq(spec.strip())
    else:
        spec = spec.strip('"')
        if spec and re.match('^[A-Za-z\.]+$', spec):
            n = getgroup(spec)
            nodes[spec] = n
            print "\t%s [label=\"%s\"] ;" % (n,spec)
            yield n

def define(name, spec):
    nodes["%%%s;" % name] = name.replace('.', '_').replace('-', '_')
    if name.endswith('att') or name.endswith('atts'):
        return
    spec = spec.strip('"')
    if not spec:
        return
    for subnode in resolve(spec):
        print '\t'+ nodes["%%%s;" % name], '->', subnode
    #print "\t%s [label=\"%s\"] ;" % (name, name+': '+spec.strip('" '))

if __name__ == '__main__':

    fn = sys.argv[-1]
#'/src/python-docutils/latest/trunk/docutils/docs/ref/docutils.dtd'
    print """digraph docutils_dtd
{
    // Generated by script-mpe/dtd2dot.py
    // Source <%s>
    // Experimental, work in progress. INVALID graph!

    scale=0.5;
    rankdir=LR;
    bgcolor=white;color=black;fontcolor=black;
    node[color=grey,fontsize=9,width=0.1,height=0.1,fontname="Bitstream Vera Sans Mono",fontcolor=black,shape="Mrecord"];
    edge[fontname="Bitstream Vera Sans Mono",color="#4e9a06"];
    ranksep=1.5;
    ranksep=0.5;
    """ % fn
    #parser = DTDParser()

    source = open(fn)
    dtd = source.read()
    rs = EN.findall(dtd)
    for name, spec in rs:
        define(name, spec)
    rs = EL.findall(dtd)
    nodecnt = 0
    for node, subclass in rs:
        for subnode in resolve(subclass.strip()):
            print '\t'+ node, '->', subnode

    #from pprint import pformat
    #print pformat(nodes)

    print """
}
    """


