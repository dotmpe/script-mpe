#!/usr/bin/env python
"""
Experiment
"""
import os, sys, re, anydbm


c = [
    '\x1b[0;0m',
    '\x1b[0;32m', # green
    '\x1b[0;37m', # white/l-gray
    '\x1b[1;37m',
    '\x1b[0;30m', # black/d-gray
    '\x1b[1;30m',
    '\x1b[0;33m', # orange
]

DB_MODE = 'n'
#DB_MODE = 'rw'

tags = anydbm.open('x-namespace.tags.db', DB_MODE)
#classes = anydbm.open('x-namespace.instances.db', DB_MODE)
classes = {}

if '' not in tags:
    tags[''] = 'Root'
    

FS_Path_split = re.compile('[\/\.\+]+').split


print '%sTagging paths in%s %s%s%s%s' % (c[5], c[0], c[1], os.path.realpath('.'), os.sep, c[0])

cwd = os.getcwd()
for root, dirs, files in os.walk(cwd):
    for name in files + dirs:
        print '%sTyping tags for%s %s%s%s' % (c[5], c[0], c[1], name, c[0])
        path = FS_Path_split(os.path.join( root, name ))
        for tag in path:
            if tag not in tags:
                type = raw_input('%s%s%s:?' % (c[6], tag, c[0]) )
                if not type: type = 'Tag'
                tags[tag] = type

        print (''.join( [ "%s %s%s:%s%s%s" %
                (c[3], tag, c[0], c[1], tags[tag], c[0])
            for tag in path if tag in tags] ))


tags.close()

