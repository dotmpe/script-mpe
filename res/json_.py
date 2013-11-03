# XXX: Dont use cjson, its buggy, see comments at
# http://pypi.python.org/pypi/python-cjson
# use jsonlib or simplejson
try:
	import simplejson as _json
except:
	import json as _json

json_read = _json.loads
json_write = _json.dumps

