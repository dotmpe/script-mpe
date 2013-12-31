# XXX: Dont use cjson, its buggy, see comments at
# http://pypi.python.org/pypi/python-cjson
# use jsonlib or simplejson
import log

loads = None
dumps = None
load = None
dump = None

try:
    import simplejson
    loads = simplejson.loads
    dumps = simplejson.dumps
    load = simplejson.load
    dump = simplejson.dump
except Exception, e:
    log.warn("Failed loading simplejson %r", e)

try:
    import ujson 
    loads = ujson.loads
    dumps = ujson.dumps
    load = ujson.load
    dump = ujson.dump

except Exception, e:
    log.warn("Failed loading ujson %r", e)

try:
    import json as json_
    log.debug("Using json")
    loads = json_.loads
    dumps = json_.dumps
    load = json_.load
    dump = json_.dump

except Exception, e:
    log.warn("Failed loading json %r", e)
    log.err("No known json library installed. Plain Python printing.")


