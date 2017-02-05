#!/usr/bin/env python
"""
2010-12-18
    pathlist2dot, terse syntax for hierarchical graphs.

    Very hacky, perhaps in-memory triple storage could help out for more
    convenient version.
    
Syntax
    - line-base
    - '#' comment lines
    - '@' attribute values
    - dir/dir/leaf
    - name:array-key:leaf
    - file.ext
    - path/[common-node]
    - [common-node]:path

"""
from getopt import getopt
import os
import re
import sys



def graph(pathfile,
    template="digraph metadata { %s }",
    title=None,
    merge_common=False,
    nonid='[\-\"\'\=\?\[\]\/\*<>\.:]+',
    colors=['red','green','blue','yellow','cyan','magenta'],
    STYLE_NODE = 'shape=record',
    STYLE_COMMON_NODE = 'shape=Mrecord',
    STYLE_ARRAY_NODE = 'shape=diamond',
    STYLE_DIR_NODE = 'shape=folder',
    STYLE_FILE_NODE = 'shape=note',
    STYLE_LEAF_NODE = 'shape=note',
        ):

    lines = [
            l for l in open(pathfile).readlines() 
            if not l.startswith('#') or not l.strip()
        ]
    coloridx = 0

    _join = lambda path:re.subn(nonid,'','_'.join(path))[0]

    out = ""
    if title:
        out = "\n\tlabel=\"%s\";" % title

    for line in lines:
        coloridx += 1
        if coloridx >= len(colors):
            coloridx = 0
        #print >>sys.stderr,len(colors), p
        attr = None
        if '@' in line:
            if line.startswith('@'):
                out += "\n\tlabel=\"%s\";\n" % line.strip('@').strip()
                continue
            p = line.find('@')
            attr = line[p+1:].strip().split('=')
            line = line[:p]
            #print >>sys.stderr,"Found attribute %s" % attr

        if '/' in line:
            line, replcnt = re.subn('/\s*', '/ ', line)
        if ':' in line:
            line, replcnt = re.subn(':\s*', ': :', line)
        if '=' in line:
            line, replcnt = re.subn('=', ' =', line)
        path = re.split('\s+', line)

        while path:
            style = ''
            node = _join(path)
            label = path.pop()
            if not label:
                continue
            if len(label)>4 and label[-4] == '.':
                style = STYLE_FILE_NODE
            if len(label)>1 and label[-1] == '/':
                style = STYLE_DIR_NODE
                label=label.strip('/')
            if len(label)>0 and (label[-1] == ':' or label[0] == ':'):
                style = STYLE_ARRAY_NODE
                label = label.strip(':')
                if not label:
                    continue
            if len(label)>1 and label[0] == '=':
                style = STYLE_LEAF_NODE
                label = label[1:]
            elif label and label[0] == '<':
                style = STYLE_NODE
                label = re.subn(nonid,'',label)[0]
            if label and label[0] == '[':
                style = STYLE_COMMON_NODE
                label = re.subn('[\[\]]','',label)[0]
                if merge_common:
                    out += "//node:%s, label:%s\n" % (node, label);
                    out += "\t%s [label=\"%s\",%s]\n;" % (label, label, style)
                    parent = _join(path)
                    if not parent:
                        continue
                    out += "\t%s -> %s [color=%s];\n" % (parent, label, colors[coloridx])
                    continue

            if attr: # attach extra attr at leaf
                style += '%s=\"%s\",' % tuple(attr)

            out += "\t%s [label=\"%s\",%s];\n" % (node, label, style)
            if attr: # attach extra attr at leaf only, and no coloured edge
                attr = None
                continue

            if path and path[-1] and path[-1][0] == '[' and merge_common:
                parent = _join([path[-1]])
            else:
                parent = _join(path)
            if not parent:
                continue
            out += "\t%s -> %s [color=%s];\n" % (parent, node, colors[coloridx])

    return template % out

### Main
NFO_001 = """   
-h  
        Help
-d file
        Load metadata ('schema' dictionary) from python file.
        Should contain template and color settings.
-t title
        Override graph/schema title
-c 
        Merge common nodes (crossing edges)
"""

WRN_001 = "Overriding edge color list with <%s>"
WRN_002 = "Setting color scheme to <%s>" 

ERR_001 = "Failed loading metadata from %s"
ERR_002 = "File does not exist: %s"
ERR_003 = "Cannot read from %s: %s"



schema = dict(merge=None,template=None,title=None,colors=None)

# parse argv
opts, args = getopt(sys.argv[1:],'hd:t:me:')

if '-h' in opts:
    print >>sys.stderr, NFO_001
    sys.exit()

meta = None

#if '-f' in opts:
#    pathfile = a
#    if not pathfile or not os.path.exists(pathfile):
#        print >>sys.stderr, ERR_002 % pathfile
#        sys.exit(-2)

#print >>sys.stderr, opts, args
for o, a in opts:
    if o == '-d':
        meta = a

# Load metadata
if not meta:
    meta = "pathlist2dot-default-template.py"
    print >>sys.stderr, WRN_002 % meta

execfile(meta)
assert schema, ERR_001 % meta

# Load edge colors
colors = schema.get('colors','')

for o, a in opts:
    if '-m' == o:
        schema['merge_common'] = True
    elif o == '-t':
        schema['title'] = a
    elif o == '-e':
        if a:
            if colors:
                print >>sys.stderr, WRN_001 % a
            colors = re.split('\s+', open(a).read())
        elif not colors:
            colors = "green blue purple orange maroon cyan magenta yellow darkgreen "\
                "burlywood coral darkorange1 darkorange4 aquamarine blue4 coral4 chocolate "\
                "chocolate4 gold goldenrod1 goldenrod4".split(' ')
        schema['colors'] = colors


# output DOT graph
for pathfile in args:
    if 'title' not in schema:
        schema['title'] = pathfile
    try:
        print graph(pathfile, **schema)
    except IOError, e:
        print >>sys.stderr, ERR_003 % (pathfile, e)
        sys.exit(-3)
    if schema['title'] == pathfile:
        schema['title'] = None


