def pick(d, *keys):
    "Generate items for given keys, with value from dict or None. "
    for key in keys:
        if key in d:
            yield key, d[key]
        else:
            yield key, None

def pluck(key, *dicts):
    "Generate values for given keys for all dicts. None for any missing. "
    for d in dicts:
        yield key in d and d[key] or None

def get_default(key, d, default=None):
    return key in d and d[key] or default

def default(key, d, default=None):
    if key in d:
        return d[key]
    v = key in d and d[key] or default
    d[key] = v
    return v

def defaults(dest, *dicts, **defaults):
    for d in dicts + ( defaults, ):
        for k in d:
            if k not in dest or not dest[k]:
                dest[k] = d[k]
    return dest

def deep_update(obj, *sources):
    for source in sources:
        for attr in list(source.keys()):
            v = source[attr]
            if isinstance(v, dict):
                dest = obj[attr]
                deep_update(dest, v)
            elif isinstance(v, list):
                if attr not in obj:
                    obj[attr] = []
                assert isinstance(obj[attr], list), obj[attr]
                obj[attr] += v
            elif attr not in obj or not obj[attr]:
                obj[attr] = v
            elif v:
                raise Exception("Cannot mixin %s = %s. Object already has value %s" % (
                    attr, v, obj[attr] ))
