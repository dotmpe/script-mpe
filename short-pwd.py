#!/usr/bin/env python
from __future__ import print_function
import sys
import os
import math


args = sys.argv[1:]
if '-h' in args or not args:
    print("Usage: %s [-h] | MAXLEN [PWD]" % __file__)
    sys.exit(0)

maxlen = int( args.pop(0) )

if args:
    pwd = args.pop()
    assert not args
else:
    pwd = os.getcwd()
home = os.path.expanduser('~')
pwd = pwd.replace(home, '~')

pwdlen = len(pwd)
if maxlen > -1:
    if maxlen > 5 and pwdlen > maxlen:
        half = math.floor( maxlen/2 )
        pwd = pwd[:int(half)-2] + '...' + pwd[0-int(half)+1:]

print(pwd)
