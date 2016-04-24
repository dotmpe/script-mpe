from fnmatch import fnmatch
from script_mpe.res import js
from script_mpe.confparse import yaml_load, yaml_safe_dump


class ArgvKeywordsParser(object):

    """
    Parse dict or list from arguments::

        a/b/c=1 a/d=2  ->  { a: { b: { c: 1 }, d: 2 } }

    """

    def __init__(self, seed=None, rootkey=None):
        super(ArgvKeywordsParser, self).__init__()
        self.data = seed
        if rootkey:
            self.scan_root_type(rootkey)

    def scan_root_type(self, key):
        if '/' in key:
            key = key.split('/')[0]
        self.data = ArgvKeywordsParser.get_data_instance(key)

    def scan_kv_args(self, args):
        " Main parse function. "
        for arg in args:
            key, value = arg.split('=')
            self.set( key, value )

    def set( self, key, value, d=None, default=None ):
        if isinstance(value, basestring) and value.isdigit():
            value = int(value)
        if d is None:
            d = self.data
        if '/' in key:
            self.set_path(key.split('/'), value)
        else:
            di = ArgvKeywordsParser.get_data_instance(key)
            if isinstance(di, list):
                pos = key.index('[')
                if key[:pos] not in d:
                    d[key[:pos]] = di
                if len(key) > pos+2:
                    idx = int(key[pos:-1])
                    d[key[:pos]][idx] = value
                else:
                    d[key[:pos]].append( value )
                return key[:pos]
            else:
                if value is None and default is not None:
                    if key not in d:
                        d[key] = default
                else:
                    d[key] = value
                return key


    def set_path( self, path, value ):
        assert isinstance(path, list), "Path must be a list"
        d = self.data
        while path:
            k = path.pop(0)
            di = ArgvKeywordsParser.get_data_instance(k)
            if path:
                k = self.set( k, None, d, di )
            else:
                k = self.set( k, value, d )
            if path:
                d = d[k]


    @staticmethod
    def get_data_instance(key):
        "Get data container instance based on key pattern"
        if fnmatch(key, '*\[[0-9]\]') or fnmatch(key, '*[]'):
            return []
        else:
            return {}



def load_data(infmt, infile):
    return readers[ infmt ]( infile )

def stdout_data(outfmt, data, outfile, opts):
    writers[ outfmt ]( data, outfile, opts )



### Readers/Writers

readers = dict(
        json=js.load,
        yaml=yaml_load
    )


def json_writer(data, file, opts):
    kwds = {}
    if opts.flags.pretty:
        kwds.update(dict(indent=2))
    file.write(js.dumps(data, **kwds))

def yaml_writer(data, file, opts):
    kwds = {}
    if opts.flags.pretty:
        kwds.update(dict(default_flow_style=False))
    yaml_safe_dump(data, file, **kwds)

writers = dict(
        json=json_writer,
        yaml=yaml_writer
    )

