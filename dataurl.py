"""
:Created: 2008-06-19
"""
from __future__ import print_function
urls = [
    'data:text/plain,Foobar,etc',
    'data:text/plain;base64,Foobar',
]

import re
for url in urls:
    groups = re.match(r"^data:([^;,]*);?([^,]*),(.*)$", url).groups()
    print(groups)
