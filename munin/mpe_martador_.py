#!/usr/bin/python
"""
"""
import os, sys


argv = list(sys.argv)
script = argv.pop(0).split('/').pop()
argstring = script.replace('mpe_martador_','')
node = ''
measure = ''

project = None
if argstring:
    node, measure = argstring.split('_')

if argv:
    if argv[0] == 'autoconf':
        print 'yes'
    elif argv[0] == 'config':
        print 'graph_category sensors'
        print 'graph_args --base 1000'
        print 'graph_title %s metrics from %s' % ( measure, node )
        print '%s_%s.label %s metrics from %s' % ( node, measure, measure, node )
        #print 'graph_vlabel (nr)'
        print '%s_%s.type GAUGE' % ( node, measure )

else:
    dp = os.path.join('/tmp/martador/', node, measure)
    print '%s_%s.value' % ( node, measure ), open(dp).read()
