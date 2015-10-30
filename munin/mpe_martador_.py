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
        print 'graph_scale no' # don't compress notation to nearest power
        if measure == 'usew':
            print 'graph_args --base 1000 --lower-limit 0'
        elif measure in ( 'use2', ):
            print 'graph_args --base 1000 --lower-limit 950 --upper-limit 1000'
        elif measure in ( 'use1', ):
            print 'graph_args --base 1000 --lower-limit 1050 --upper-limit 1100'
        else:
            print 'graph_args --base 1000'
        print 'graph_title %s metrics from %s' % ( measure, node )
        print '%s_%s.label %s metrics from %s' % ( node, measure, measure, node )
        #print 'graph_vlabel (nr)'
        print '%s_%s.type GAUGE' % ( node, measure )

else:
    v = ''
    vs = []
    dp = os.path.join('/tmp/martador/', node, measure)
    try:
        vs = open(dp).readlines()
        open(dp, 'w+').close()
    except:
        pass
    if len(vs) > 1:
        v = vs[0]
    elif len(vs) > 1:
        v = sum(vs)/len(vs)
    else:
        v = ''
    print '%s_%s.value' % ( node, measure ), v
