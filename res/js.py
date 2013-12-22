# XXX: Dont use cjson, its buggy, see comments at
# http://pypi.python.org/pypi/python-cjson
# use jsonlib or simplejson

try:
    import simplejson as _json
    loads = _json.loads
    dumps = _json.dumps
except:
    try:
        import ujson as _json
        loads = _json.loads
        dumps = _json.dumps

    except:
        try:
            import json as _json
            loads = _json.loads
            dumps = _json.dumps

        except:
            print >>sys.stderr, "No known json library installed. Plain Python printing."
            loads = None
            dumps = None



