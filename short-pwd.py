#!/usr/bin/env python
from __future__ import print_function
import sys
import os
import math

maxlen = int( sys.argv[1] )

if len(sys.argv) > 2:
    pwd = sys.argv[2].strip()
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
