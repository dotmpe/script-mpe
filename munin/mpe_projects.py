#!/usr/bin/python

"""
"""
import os
import sys
import re
import time
import socket
from pprint import pformat


projects = [
            'htcache'
        ]
branches = {
        'htcache': (
                'dev',
                'master',
                'dev_domaindb',
                'dev_dhtmlui',
                'dev_proxyreq',
                'dev_cachemaint',
                'dev_relstore',
            )
        }

argv = list(sys.argv)
host = socket.gethostname()
script = argv.pop(0)
argstring = script.replace('mpe_project_','')
measure = 'loc'
project = None
if argstring:
    parts = argstring.split('_')
    if len(parts) == 1:
        measure, = parts
    elif len(parts) == 2:
        measure, project = parts

if argv:
    if argv[0] == 'autoconf':
        print 'yes'
    elif argv[0] == 'config':

        print 'graph_category projects'
        print 'graph_args --base 1000'
        print 'graph_title %s: Project %r metrics' % (host, measure)

        if measure == 'count':
            print 'graph_vlabel (nr)'
            for p in projects:
                print '%s_count.label %s' % p
                print '%s_count.type GAUGE' % p

        elif measure == 'loc':
            print 'graph_vlabel (loc)'
            for p in projects:
                print '%s_loc.label %s' % p
                print '%s_loc.type GAUGE' % p

        elif measure == 'loc-detail':
            assert project
            print 'graph_vlabel (loc)'
            print '%s_conf_loc.label %s' % project
            print '%s_conf_loc.type GAUGE' % project
            print '%s_tpl_loc.label %s' % project
            print '%s_tpl_loc.type GAUGE' % project
            print '%s_src_loc.label %s' % project
            print '%s_src_loc.type GAUGE' % project

        elif measure == 'tests':
            assert project
            print 'graph_vlabel (tests)'
            for b in branches[project]:
                print '%s_passed_tests.label %s passed' % project
                print '%s_passed_tests.type GAUGE' % project
                print '%s_passed_tests.draw AREASTACK'
                print '%s_failure_tests.label %s failures' % project
                print '%s_failure_tests.type GAUGE' % project
                print '%s_failure_tests.draw AREASTACK' % project
                print '%s_error_tests.label %s errors' % project
                print '%s_error_tests.type GAUGE' % project
                print '%s_error_tests.draw AREASTACK' % project

        elif measure == 'git-branches':
            pass

else:
    if measure == 'count':
        update()
        for p in projects:
            pass

    elif measure == 'loc':
        pass

    elif measure == 'loc-detail':
        assert project

    elif measure == 'tests':
        r = {}
        p = os.path.expanduser('~/project/%s/test-results.tab' % project)
        if not os.path.exists(p):
            sys.exit()
        data = open(p)
        lines = data.readlines()
        lines.reverse()
        for l in lines:
            p = l.strip().split(', ')
            if l.startswith('#'):
                assert len(p) == 7, len(p)
                continue
            assert len(p) == 7, l
            datetime, host, branch, rev, testtype, passed, errors = p
            if branch not in r:
                r[branch] = { testtype : ( (passed, errors), (datetime, host, rev,) ) }
            elif testtype not in r[branch]:
                r[branch][testtype] = (passed, errors), (datetime, host, rev)
        data.close()
#        print pformat(r)
        for k in r:
            for t in 'unit', 'system':
                if t in r[k]:
                    print "%s_tests_%s_passed.value" % (k, t,), r[k][t][0][1]
                    print "%s_tests_%s_errors.value" % (k, t,), r[k][t][0][0]

