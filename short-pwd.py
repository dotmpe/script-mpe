#!/usr/bin/env python
import sys
import os
import math

maxlen = int( sys.argv[1] )

pwd = os.getcwd()
home = os.path.expanduser('~')
pwd = pwd.replace(home, '~')

pwdlen = len(pwd)
if pwdlen > maxlen:
	half = math.floor( maxlen/2 )
	pwd = pwd[:int(half)-2] + '...' + pwd[0-int(half)+1:]

print pwd	
