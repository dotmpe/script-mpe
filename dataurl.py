urls = [
	'data:text/plain,Foobar,etc',
	'data:text/plain;base64,Foobar',
]

import re
for url in urls:
	groups = re.match(r"^data:([^;,]*);?([^,]*),(.*)$", url).groups()
	print groups

