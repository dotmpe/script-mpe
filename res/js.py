# XXX: Dont use cjson, its buggy, see comments at
# http://pypi.python.org/pypi/python-cjson
# use jsonlib or simplejson
from script_mpe import log, confparse
from script_mpe.confparse import Values, yaml_load, yaml_dump


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
except Exception as e:
    pass#log.warn("Failed loading simplejson %r", e)

try:
    import ujson
    loads = ujson.loads
    dumps = ujson.dumps
    load = ujson.load
    dump = ujson.dump

except Exception as e:
    pass#log.warn("Failed loading ujson %r", e)

try:
    import json as json_
    log.debug("Using json")
    loads = json_.loads
    dumps = json_.dumps
    load = json_.load
    parse = loads
    import sys
    def dump(data):
        json_.dump(data, sys.stdout)

except Exception as e:
    pass#log.warn("Failed loading json %r", e)


if not loads:
    log.err("No known json library installed. Plain Python printing.")

def require(self):
    if not loads:
        import sys
        sys.exit(1)


class AbstractYamlDocs(object):

    """
    Mixing type with simple tooling to load a YAML document to an attribute
    on self.
    """

    def get_yaml(self, name, defaults=None):
        """
        Subtype should implement path lookup for name, or assign one using
        defaults to initialize document.
        """
        raise NotImplementedError()

    def load_yaml(self, name, defaults=None, **kwds):
        """
        Create and/or load and return YAML document.
        """
        p = self.get_yaml(name, defaults=defaults)
        return yaml_load(open(p), **kwds)

    def save_yaml(self, p, doc, **kwds):
        """
        Dump document at `p`, pass keywords to `ruamel.yaml` dumper.
        """
        yaml_dump(open(p, 'w+'), doc, **kwds)

    def yamldoc(self, name, defaults=None, **kwds):
        """
        Create and/or load and YAML document to ``self.<name>doc``.
        """
        if name.endswith('doc'): a = name
        else: a = name+'doc'
        assert not hasattr(self, a), name
        doc = self.load_yaml(name, defaults=defaults, **kwds)
        setattr(self, a, doc)
        setattr(self, "%s_filename" % a, name)
        return doc

    def yamlsave(self, name, **kwds):
        """
        Map name to path with get-yaml, and dump document at ``self.<name>doc``
        to that location.
        """
        if name.endswith('doc'): a = name
        else: a = name+'doc'
        doc = getattr(self, a)
        p = self.get_yaml(name)
        self.save_yaml(p, doc, **kwds)
