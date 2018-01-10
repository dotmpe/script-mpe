import zope.interface

from script_mpe.confparse import yaml_loads, yaml_dumps, yaml_load, yaml_dump
from script_mpe.res import js

from . import iface


class JSONLike:
    zope.interface.implements(iface.IJSONLike)

    """
    Collection of load/dump functions.
    """

    # JSON

    def load_json(self, *args, **kwds):
        return js.load(*args, **kwds)

    def dump_json(self, *args, **kwds):
        return js.dump(*args, **kwds)

    def loads_json(self, *args, **kwds):
        return js.loads(*args, **kwds)

    def dumps_json(self, *args, **kwds):
        return js.dumps(*args, **kwds)

    # YAML

    def load_yaml(self, *args, **kwds):
        return yaml_load(*args, **kwds)

    def dump_yaml(self, *args, **kwds):
        return yaml_dump(*args, **kwds)

    def loads_yaml(self, *args, **kwds):
        return yaml_loads(*args, **kwds)

    def dumps_yaml(self, *args, **kwds):
        return yaml_dumps(*args, **kwds)

# site.registerUtility(JSONLike(), IJSONLike)
