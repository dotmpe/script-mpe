import sys

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
        "Initialize root (self.data) to correct data type: dict or list"
        if '/' in key:
            key = key.split('/')[0]
        self.data = ArgvKeywordsParser.get_data_instance(key)

    def scan(self, fh):
        " Parse from file, listing one kv each line. "

        # XXX: need bufered read..
        pos = fh.tell()
        if self.data is None:
            rootkey = fh.read(1)
            while rootkey[-1] != '=':
                rootkey += fh.read(1)
            self.scan_root_type(rootkey)
            fh.seek(pos)

        for line in fh.readlines():
            self.set_kv(line)

    def scan_kv_args(self, args):
        " Parse from list of kv's. "
        for arg in args:
            self.set_kv(arg)

    def set_kv(self, kv):
        " Split kv to key and value, the the first '=' occurence. "
        if '=' not in kv: return
        pos = kv.index('=')
        key, value = kv[:pos].strip(), kv[pos+1:].strip()
        self.set( key, value )


    def set( self, key, value, d=None, default=None ):
        """ Parse key to path within dict/list struct and insert value.
        kv syntax::

            list[] = value
            key = value
            key/sub = value

        Append value to a list::

            key/list[5]/subkey/mylist[] = value

        """
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

def kv_reader(file):
    data_obj = ArgvKeywordsParser()
    data_obj.scan(file)
    return data_obj.data

readers = dict(
        json=js.load,
        yaml=yaml_load,
        kv=kv_reader
    )


def kv_writer(data, file, opts):
    pass

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
        yaml=yaml_writer,
        kv=kv_writer
    )


### Misc. argument/option handling

def get_src_dest(opts):
    infile, outfile = None, None
    if opts.args.srcfile:
        if opts.args.srcfile == '-':
            infile = sys.stdin
        else:
            infile = open(opts.args.srcfile)
        if 'destfile' in opts.args and opts.args.destfile:
            if opts.args.destfile == '-':
                outfile = sys.stdout
            else:
                outfile = open(opts.args.destfile)
    return infile, outfile

def get_src_dest_defaults(opts):
    infile, outfile = get_src_dest(opts)
    if not outfile:
        outfile = sys.stdout
        if not infile:
            infile = sys.stdin
    return infile, outfile


