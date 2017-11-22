#!/usr/bin/env  python
"""
:created: 2017-05-06

Given a urllib retrievable, concatenate some hashsums and other attributes into
a magnet URI.

Current implementation is a rough first working version with some notes and
todos, but is mostly complete and only needs some fine-tuning for specific
scenario's.

"""
from __future__ import print_function

__description__ = "magnet - "
__version__ = '0.0.4-dev' # script-mpe
__usage__= """
Usage:
    magnet.py [options] [ FILE | URI ] [ CTX ] [ [ XS | AS | DN | XT ]... ]
        [ --no-mt | --mt=MT... ]
        [ --no-dn | --dn=DN... ] [ --no-add-dn ]
        [ --no-xs | --xs=XS... ] [ --no-src-xs ] [ --no-add-xs ]
        [ --no-as | --as=AS ]
        [ --no-xt | --xt=XT... ] [ --no-add-xt ] [ --xt-type=XTC... ]
        [ --no-xl ]
        [ --no-uri ]
        [ --no-ed2k ]
        [ --no-btih ]
        [ --no-md5 ]
        [ --no-sha1 ]
        [ --no-tiger ]
        [ --no-gost ]
        [ --no-aich ]
        [ --no-crc32 ]
        [ --no-aich ]
        [ --no-be | --init-be ]

Options:
    --mt-type=FMT
                  Explicitly provide format for MT locator or name.
    --output-format=FMT
                  Format to apply to stdout printing (unless quiet).
    --debug       ..
    --verbose     ..
    --quiet       ..
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).


Dereference content at URI, and create `magnet:` URI. Ouput the URI to stdout,
or append it to a file.

The generic arg. seq. is:

FILE | URI
    1. locator to primary content
CTX
    2. context to primary, a container locator. Like .rss, .magma.
XS | AS
    3. additional exact or acceptable names
DN
    If not given, the basename of file, or content-disposition or basename of
    URI path is used for display name ``dn``. Unless ``--no-dn`` is set.
    Using the default can also be prevented by using ``--dn``, or by allowing
    additional arguments to be local names (like file paths or basenames)
    (ie. no ``--no-add-dn`` passed).

With magnets, a topic refers to a tag or metadata value more or less indicating
a particular resource. Or set of resources maybe. While a source is a locator
in the form of a regular http, or perhaps some P2P link. But other attributes
like 'kt' and 'tr' can also provide for some baseline for retrieval of the
primary resource indicated.

Generally the difference of a XS vs. a XT is not clear to me currently. It
depends on the scheme of xs or as perhaps also. But that of XT generally is some
kind of content hashing scheme. In any case, according the the [WP]_ table, MT
seems to be both URN or URL, while XX/AS are http/ftp/dchub scheme (ie. URL of
sorts), and XT is exclusively URN.

Arguments are parsed as a complete and final array, iow. options can follow
arguments.

--mt=MT
    The manifest-topic property can link to manifests. It can be a http or
    urn:sha1 for example, and the resource it points at is to be used to provide
    a context for the subject. Which would usually be a simple list, and/or
    provide additional information about the subject resource. Like an outline?
    Or home document.

    TODO: should support (somewhat) .magma, .list (todo.txt compat) and maybe
    .rss and/or .rst, .md, wiki also.

--no-uri
    Disables validating the primary locator for some reason. Also causes it
    to use local absolute or relative paths as-is for XS attribute.

--as=...

--no-xs
    ..
--no-add-xs
    Normally additional names are used as XS refs. Passing this option causes
    them to be set as AS refs instead.

--xs=XS
    Exact sources list alternatives to the primary locator. XS refs can be
    passed as additional arguments, if a ``--mt`` or ``CTX`` (empty or not)
    is provided first and ``--as`` is not present. Otherwise use this option.

--xt=XT
    Sets an exact topic. This usually is a URN for checksum type of indicator
    for a stream or hashable (local file, http entity etc.). Multiple arguments
    required.

--no-dn
    Prevents adding dn. Iow. do not set default, and ignore given ``--dn`` or
    DN from AS/XS. See also *DN*.

--no-add-dn
    Prevents filtering of DN from AS/XS args. This does not affect the
    ``--no-dn`` setting, but only disables the validation for AS/XS args.
    Allows to keep values that do not look like URN still as AS/XS refs,
    see also ``--no-uri``.

--no-xl
    Prevents adding the exact length property `xl`.

Done:
    | W.o. ``--mt``, second arg is the list.
    |

TODO:
Any further arg is either AS, XS, XT or DN.
AS or XS is URIRef compatible. W.o. ``--no-dn``
Print simple keys, but add index number for multiple occurences (not sure as to
standard, but this should work better with simple to-dict parsing).
W.o. ``--no-be`` does not try to invoke a save-to-context for the generated
magnet. Otherwise open files and add the generated magnet as a reference.

""" % ( __version__, )

from datetime import datetime
import hashlib
import sys
import os
import re
import subprocess
import tempfile
import urllib
import urllib2
from StringIO import StringIO


import uriref
import libcmd_docopt

from confparse import yaml_load, yaml_safe_dumps

mhashlib= None # FIXME: malloc troubs
#import mhashlib # py-mhash 1.2


def cmd_magnet_rw(FILE, URI, CTX, DN, XS, AS, XT, opts, settings):
    """
    """

    # Process arguments
    if uriref.scheme.match(FILE):
        URI = FILE
        FILE = None
    if not opts.flags.quiet and opts.flags.debug:
        print('FILE', FILE, file=sys.stderr)
        print('URI', URI, file=sys.stderr)
    ARGS_ =  XS + AS + DN + XT
    XS, AS, DN, XT = [], [], [], []
    REFS_, TOPICS_ = [], []
    if CTX:
        CTX = [ CTX ]
    else:
        CTX = []
    if opts.flags.mt:
        if CTX:
            ARGS_ = CTX + ARGS_
        CTX = opts.flags.mt
    if opts.flags['dn']:
        DN += opts.flags['dn']
    if opts.flags['as']:
        AS += opts.flags['as']
    if opts.flags['xs']:
        XS += opts.flags['xs']
    if opts.flags['xt']:
        XT += opts.flags['xt']
    if not opts.flags.quiet and opts.flags.debug:
        print('CTX', CTX, file=sys.stderr)
        print('DN', DN, file=sys.stderr)
    if not opts.flags.no_add_dn:
        for a in ARGS_:
            if os.path.exists(os.path.dirname(os.path.expanduser(a))):
                CTX.append(a)
                continue
            if a.startswith(os.sep):
                print("Warning, arg %r looks it may be a " % a,
                    +"local path for context, but its directory path does not "
                    +"exist so the value will ignored", file=sys.stderr )
            m = uriref.absoluteURI.match(a)
            if m:
                if a.startswith('urn:'):
                    TOPICS_.append(a)
                else:
                    REFS_.append(a)
            else:
                if os.path.exists(a):
                    # NOTE: allow relative paths, but need more elegant
                    # path-part handling. perhaps some topic hierarchy
                    if os.path.startswith(os.sep):
                        DN.append(os.path.basename(a))
                    else:
                        DN.append(os.path.basename(a))
    if not opts.flags.quiet and opts.flags.debug:
        print('DN', DN, file=sys.stderr)
    if not opts.flags.no_add_xt:
        XT += TOPICS_
    if not opts.flags.no_add_xs:
        XS += REFS_
    else:
        AS += REFS_
    if not opts.flags.no_uri:
        if not URI:
            #if not FILE.startswith('/'):
            FILE = os.path.abspath(FILE)
            URI = 'file://'+FILE
        uriref.URIRef(URI)

    if not opts.flags.no_src_xs:
        XS = [ urllib.quote(URI, safe='') ] + XS

    if not opts.flags.no_dn:
        if not DN:
            if FILE:
                bn = os.path.basename(FILE)
            else:
                bn = os.path.basename(urllib.unquote(URI))
            DN.append(urllib.quote(bn))

    if opts.flags.debug:
        print('DN', DN, file=sys.stderr)
        print('XS', XS, file=sys.stderr)
        print('AS', AS, file=sys.stderr)
        print('XT', XT, file=sys.stderr)

    query = {}

    # Dereference entity and resolve some attributes
    if not opts.flags.xt_type:
        opts.flags.xt_type = [
            'urn:sha1',
            'urn:md5',
            'urn:btih',
            'urn:tree:tiger',
            'urn:aich',
            'urn:ed2k',
            'urn:crc32'
        ]

    urlinfo = urllib.urlopen(URI)
    info = urlinfo.info()
    status = urlinfo.getcode()
    if status and status is not 200:
        print('HTTP status', status, file=sys.stderr)
        return status/100
    data = urlinfo.read()
    fn = tempfile.mkstemp()[1]
    open(fn, 'w+').write(data)

    if not opts.flags.no_xl:
        query['xl'] = info['content-length']

    for xt_c in opts.flags.xt_type:
        if xt_c not in resolvers:
            print("No resolver %r" % xt_c)
            continue
        if not getattr(opts.flags, 'no_%s' % xt_c.split(':')[-1]):
            XT.append( xt_c +':'+ resolvers[ xt_c ]( data, info, fn ) )

    # Prepare topic context backend(s)
    bes = {}
    if not opts.flags.no_be:
        for be_spec in list(CTX):
            be = get_magnet_backend(be_spec)
            bes[be_spec] = be
            if not be.exists():
                if opts.flags.init_be:
                    be.init()
                else:
                    CTX.remove(be_spec)
    else:
        for ref in list(CTX):
            if not uriref.absoluteURI.match(ref):
                CTx.remove(be_spec)

    # Create magnet URI
    magnet = dict(scheme='magnet', query=query)
    for p, P, isUri in [
            ( 'dn',DN,0 ),
            ( 'xs',XS,1 ),
            ( 'xt',XT,1 ),
            ( 'mt',CTX,1 ),
            ( 'as',AS,1 ),
    ]:
        if opts.flags['no_%s' % p]:
            continue

        refs = list(P)
        if isUri:
            for idx, ref_enc in enumerate(P):
                ref = urllib.unquote(ref_enc)
                if not uriref.absoluteURI.match(ref):
                    pref = os.path.abspath(os.path.expanduser(ref))
                    if os.path.exists(os.path.dirname(pref)):
                        refs[idx] = 'file://'+pref
                    else:
                        refs[idx] = 'urn:'+ref

        if len(refs) == 1:
            magnet['query'][p] = refs[0]
        else:
            i =  1
            for x in refs:
                magnet['query']['%s.%i' % (p,i)] = x
                i += 1

    # Format for stdout
    magnet_uri = u"%s:?%s" % ( magnet['scheme'], "&".join([
        "%s=%s" % ( k,str(v) ) for k,v in magnet['query'].items() ]) )

    # Check with/add to backend
    if not opts.flags.no_be:
        for spec, be in bes.items():
            if not be.contains(magnet_uri):
                be.append(magnet_uri)
                be.save()

    # Output
    print(magnet_uri)


# NOTE: crude pastandalone impl. See res.txt for ideas to cleanup.

class MagnetFileStore:
    save_mode = 'w+'
    def __init__(self, fn):
        self.fn = fn
        self.path = os.path.abspath(os.path.expanduser(fn))
        self.initialize_new()
        if os.path.exists(self.path):
            self.data = self.parse_file(self.path)
    def exists(self):
        return os.path.exists(self.path)
    def contains(self, ref):
        return ref in self.data
    def init(self):
        self.initialize_new()
        self.save()
    def save(self):
        d = os.path.dirname(self.path)
        if not os.path.exists(d):
            os.makedirs(d)
        self.dump(open(self.path, self.save_mode))
    def dump(self, fp):
        data = self.serialize()
        fp.write(os.linesep+data)
    def parse_file(self, fn):
        return self.parse(open(fn).read())
    def parse(self, data):
        raise NotImplementedError()
    def serialize(self):
        raise NotImplementedError()
    def initialize_new(self):
        self.data = []
    def append(self, ref):
        self.data.append(ref)
class MAGMA(MagnetFileStore):
    def parse_file(self, fn):
        data = yaml_load(open(fn))
        if data:
            return data['list']
        return []
    def parse(self, data):
        return yaml_load(StringIO(data))['list']
    def serialize(self):
        # FIXME: spec requires double quotes, not single for magnet items
        return yaml_safe_dumps({'list': self.data})
class TxtItemList(MagnetFileStore):
    def parse(self, data):
        l = []
        # NOTE: this does not comparer magnets properly, re-ordered attrs. cause
        # new entries to be written
        for ref in re.finditer('<[^>]*>', data):
            ref = ref.group()[1:-1]
            if ref.lower().startswith('URL:'):
                ref = ref[4:]
            if not uriref.scheme.match(ref):
                continue
            if not uriref.absoluteURI.match(ref):
                raise Exception("Parse error in TxtItemList: uriref mismatch %r"
                        % ref)
            l.append(unicode(ref))
        return l
    def serialize(self):
        return os.linesep.join([ "<%s>" % i for i in self.data ])
class ReStDoc(TxtItemList):
    save_mode = 'a+'

def get_magnet_backend(spec):
    if spec.endswith('.magma'):
        return MAGMA(spec)
    if spec.endswith('.rst'):
        return ReStDoc(spec)
    if spec.endswith('.list'):
        return TxtItemList(spec)



# FIXME: should really intialize some tool to XT key mapping in rc file

resolvers = {
        #'urn:ed2k': '',
        #'urn:bitprint': '',
        #'urn:btih': '',
        'urn:sha1': lambda data, info, path: hashlib.sha1(data).hexdigest().upper(),
        'urn:md5': lambda data, info, path: hashlib.md5(data).hexdigest().upper(),
    }

if mhashlib:
    resolvers.update({
        'urn:tree:tiger': lambda data, info, path: mhashlib.tiger(path).hexdigest().upper(),
        # some other hashes from mhash.
        # TODO: haval should have a rounds param, not sure to what it is set
        #'urn:haval128': lambda data, info, path: mhashlib.haval128(data).hexdigest().upper(),
        #'urn:haval192': lambda data, info, path: mhashlib.haval192(data).hexdigest().upper(),
        #'urn:haval224': lambda data, info, path: mhashlib.haval224(data).hexdigest().upper(),
        #'urn:haval256': lambda data, info, path: mhashlib.haval256(data).hexdigest().upper(),
        'urn:gost': lambda data, info, path: mhashlib.gost(path).hexdigest().upper(),
        'urn:crc32b': lambda data, info, path: mhashlib.crc32b(path).hexdigest().upper(),
        'urn:crc32': lambda data, info, path: mhashlib.crc32(path).hexdigest().upper()
    })



import zlib

class crc32(object):
    name = 'crc32'
    digest_size = 4
    block_size = 1

    def __init__(self, arg=''):
        self.__digest = 0
        self.update(arg)

    def copy(self):
        copy = super(self.__class__, self).__new__(self.__class__)
        copy.__digest = self.__digest
        return copy

    def digest(self):
        return self.__digest

    def hexdigest(self):
        return '{:08x}'.format(self.__digest)

    def update(self, arg):
        self.__digest = zlib.crc32(arg, self.__digest) & 0xffffffff

# Now you can define hashlib.crc32 = crc32
import hashlib
hashlib.crc32 = crc32

# Python > 2.7: hashlib.algorithms += ('crc32',)
hashlib.algorithms += ('crc32', )
# Python > 3.2: hashlib.algorithms_available.add('crc32')



for algo in hashlib.algorithms:
    k = 'urn:%s' % algo
    if k in resolvers: continue
    resolvers[k] = lambda data, info, path: getattr(hashlib, algo)(data).hexdigest().upper()


lt = None
try:
  import libtorrent as lt
except ImportError as e:
  pass

if lt:
    resolvers['urn:btih'] = lambda data, info, path: lt.torrent_info(data).info_hash()


def rhash(path, name):
    cmd = [ 'rhash', '--simple', '--%s' % name, path ]
    line = subprocess.check_output(cmd)
    line = line.split('  ')
    return line[0]
resolvers['urn:crc32'] = lambda data, info, path: rhash(path, 'crc32')
resolvers['urn:tree:tiger'] = lambda data, info, path: rhash(path, 'tiger')
resolvers['urn:gost'] = lambda data, info, path: rhash(path, 'gost')
resolvers['urn:aich'] = lambda data, info, path: rhash(path, 'aich')
resolvers['urn:has160'] = lambda data, info, path: rhash(path, 'has160')
resolvers['urn:snefru128'] = lambda data, info, path: rhash(path, 'snefru128')
resolvers['urn:ripemd160'] = lambda data, info, path: rhash(path, 'ripemd160')
resolvers['urn:ed2k'] = lambda data, info, path: rhash(path, 'ed2k')
resolvers['urn:btih'] = lambda data, info, path: rhash(path, 'btih')


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(rc, opts):

    """
    Execute using docopt-mpe options.
    """

    settings = opts.flags
    opts.default = 'magnet-rw'
    opts.flags.verbose = not opts.flags.quiet
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'magnet/%s' % __version__

if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf-8')
    RC = os.getenv('MAGNET_RC', '~/.magnet-py-rc')
    if os.path.exists(os.path.expanduser(RC)):
        rc = {}
    else:
        rc = {}
    opts = libcmd_docopt.get_opts(__doc__ + __usage__, version=get_version())
    sys.exit(main(rc, opts))
