#!/usr/bin/env python
"""Walk paths according to excludes, print paths and/or attributes.

TODO:
- auto name disks/mount points
- inherited exclude rules
- any number of named pathsets
- exclude rule tags per contexts

Make context specific, but dont accept path arguments "outside"::

    finfo.py [options] PATH myexec
    finfo.py [options] PATH=. my-file-in-path
    finfo.py [options] [PWD] my-local-file

    finfo.py [options] DIR=~/mydir my/path/in/dir
    finfo.py [options] HTDOCS personal/journal

Iow. no absolute paths, relative paths, symlinks going elsewhere, etc;
all path arguments parse to (canonical) named root.

TODO: Keep catalog of file format descriptions for local paths
XXX: Verify valid extensions for format.
XXX: Keep complete resource description

----

2011 stuff:

Schema
------
``taxus.media``
  Mediameta:Node
    * checksums:List<ChecksumDigest>
    * mediatype:Mediatype
    * mediaformat:Mediaformat
    * genres:List<Genre>

  Mediatype:Node
    * mime:Name

  MediatypeParameter:None
    * localName:Str
    * default:

  Genre:Node
    ..

  Mediaformat:Name
    ..

``taxus.web``
  CachedContent:INode
    * cid:String
    * size:Int
    * charset:String
    * partial:Boolean
    * etag:String
    * expires:DateTime
    * encodings:String
  Status
    * http_code:Int
  Resource:Node
    * status:STatus
    * location:Locator
    * last_access/modified/update
    * allow:String
  Invariant:Resource
    * content:CachedContent
    * language:String
    * mediatype:String
  Variant:Resource
    ..

[2016-10-11] Adding simpler docopts-mpe based frontend.
"""
from __future__ import print_function

__description__ = "finfo - walk paths, using ignore dotfiles, get attributes"
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.finfo.sqlite'
__usage__ = """
Usage:
  finfo.py [options] [--env name=VAR]... [--name name=VAR]... (CTX|FILE...|DIR...)
  finfo.py --list
  finfo.py [options] --delete PATH
  finfo.py --show-info
  finfo.py --list-prefixes
  finfo.py -h|--help
  finfo.py --version

Manage INode collection: track local files with res.metafile.
use named basedirs to convert local paths to global IDs.

Options:
    --auto-prefix
                  Look for prefix per given argument.
    --update
                  Update records from files.
    --list
                  List records, don't use filesystem.
    --names-only
                  Print prefix with names only, don't use records.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    -n name=PATH --name name=PATH[:PATH]
                  Define a name with path(set), to look for existing paths
                  and/or replace prefix common path prefixes with 'name:'.
    -e VAR=name --env VAR=name
                  Bind env 'VAR' to named set 'name'. If env isset overrides any
                  named set (see --name).
                  [default: PWD=pwd] (and PWD evaluates to .)
    -f --files
                  Return files only.
    -d --directories
                  Return directories only.
    -r --recurse
                  Recurse
    --config NAME
                  Config [default: cllct.rc]
    --documents
                  Return document type files only.
    --filter INCLUDE...
                  ..
    --show-info   ..
    --dry-run     ..

Other flags:
    -v            Increase verbosity.
    -h --help     Show this usage description. For a command and argument
                  description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__, )
import os
from datetime import datetime
from pprint import pprint, pformat
import re

from sqlalchemy import Column, Integer, String, Boolean, Text, create_engine,\
                        ForeignKey, Table, Index, DateTime, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref

from script_mpe.libhtd import *


models = [
        Mediatype,
        INode,
        Dir,
        File,
        Mount,
        TNode
    ]


default_filters = [
            re.compile('^[^\.(git|svn|bzr|build)]$')
        ]

doc_exts = "doc docx pdf tex latex troff man rst md txt".split(' ')
doc_filters = [
            re.compile('^.*\.(%s)$' % '|'.join(doc_exts))
        ]


class FileInfoApp(rsr.Rsr):

    NAME = 'mm'
    PROG_NAME = os.path.splitext(os.path.basename(__file__))[0]

#    DB_PATH = os.path.expanduser('~/.fileinfo.db')
#    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

#    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['file_info']
    #NONTRANSIENT_OPTS = Cmd.NONTRANSIENT_OPTS
    DEFAULT = ['file_info']

    DEPENDS = {
            'file_info': ['rsr_session'],
            'name_and_categorize': ['rsr_session'],
            'mm_stats': ['rsr_session'],
            'list_mtype': ['rsr_session'],
            'list_mformat': ['rsr_session'],
            'add_genre': ['rsr_session'],
            'add_mtype': ['rsr_session'],
            'add_mformats': ['rsr_session']
        }

    @classmethod
    def get_optspec(Klass, inheritor):
        p = inheritor.get_prefixer(Klass)
        return (
                p(('--file-info',), libcmd.cmddict(help="Default command. ")),
                p(('--name-and-categorize',), libcmd.cmddict(
                    help="Need either --interactive, or --name, --mediatype and "
                        " --mediaformat. Optionally provide one or more --genre's. "
                )),
                p(('--stats',), libcmd.cmddict(help="Print media stats. ")),
                p(('--list-mtype',), libcmd.cmddict(help="List all mediatypes. ")),
                p(('--list-mformat',), libcmd.cmddict(help="List all media formats. ")),
                p(('--add-mtype',), libcmd.cmddict(help="Add a new mediatype. ")),
                p(('--add-mformats',), libcmd.cmddict(help="Add a new media format(s). ")),
                p(('--add-genre',), libcmd.cmddict(help="Add a new media genre. ")),

                p(('--name',), dict(
                    type='str'
                )),
                p(('--mtype',), dict(
                    type='str'
                )),
                p(('--mformat',), dict(
                    type='str'
                )),
                p(('--genres',), dict(
                    action='append',
                    default=[],
                    type='str'
                ))
               # (('-d', '--dbref'), {'default':self.DEFAULT_DB, 'metavar':'DB'}),
            )

    def list_mformat(self, sa):
        mfs = sa.query(Mediaformat).all()
        for mf in mfs:
            print(mf)

    def list_mtype(self, sa=None):
        mms = sa.query(Mediatype).all()
        for mm in mms:
            print(mm)

    def mm_stats(self, sa=None):
        mfs = sa.query(Mediaformat).count()
        log.note("Number of mediaformat's: %s", mfs)
        mts = sa.query(Mediatype).count()
        log.note("Number of mediatype's: %s", mts)
        mms = sa.query(Mediameta).count()
        log.note("Number of mediameta's: %s", mms)

    def add_genre(self, genre, supergenre, opts=None, sa=None):
        log.crit("TODO add genre %s %s", genre, supergenre)

    def add_mtype(self, mtype, label, opts=None, sa=None):
        """
        Add one or more new mediatypes.
        """
        assert mtype, "First argument 'mtype' required. "
        mt = sa.query( Mediatype )\
                .filter( Mediatype.name == mtype )\
                .all()
        if mt:
            mt = mt[0]
        if mt:
            log.warn('Existing mtype %s', mt)
            yield 1
        if not label:
            label = mtype
        mtn = Name( name=mtype, date_added=datetime.now() )
        mt = Mediatype( name=label, mime=mtn, date_added=datetime.now() )
        log.info('New type %s', mt)
        sa.add(mt)
        sa.commit()
        yield dict(mtn=mtn)
        yield dict(mt=mt)

    def add_mformats(self, opts=None, sa=None, *formats):
        """
        Add one or more new mediaformats.
        """
        for fmt in formats:
            mf = Mediaformat.find((
                    Mediaformat.name == fmt,
                ), sa=sa)
            if mf:
                log.warn('Existing mformat %s', mf)
                continue
            if opts.interactive: # XXX: add_mformats interactive
                mfs = Mediaformat.search(name=fmt)
                print('TODO', mfs)
            mf = Mediaformat( name=fmt, date_added=datetime.now() )
            log.info('New format %s', mf)
            sa.add(mf)
            yield dict(mf=mf)
        sa.commit()

# TODO: adding Mediameta for files
    def name_and_categorize(self, opts=None, sa=None,
            name=None, mtype=None, mformat=None, genres=None, *paths):
        if len(paths) > 1:
            assert opts.interactive
            for path in paths:
                for subpath in res.fs.Dir.walk(paths, opts):#dict(recurse=True)):
                    print(subpath)
        elif not opts.interactive:
            path = paths[0]
            mm = Mediameta(name=name)
            if mtype:
                mt = [ ret['mt'] for ret in self.add_mtype( mtype, None, opts=opts, sa=sa )
                        if 'mt' in ret ].pop()
                mm.mediatype = mt
            if mformat:
                mf = [ ret['mf'] for ret in self.add_mformats( opts, sa, mformat )
                        if 'mf' in ret ].pop()
                mm.mediaformat = mf
            if genres:
                mm.genres = [ ret['genre']
                        for ret in self.add_genre( genre, None, opts=opts, sa=sa )
                        if 'genre' in ret ]
            sa.add(mm)
            sa.commit()
            log.note("Created media %s", mm)

    def file_info(self, args=None, sa=None):
        for p in args:
            for p in res.fs.Dir.walk(p):
                format_description = lib.cmd('file -bs "%s"', p).strip()
                mediatype = lib.cmd('file -bi "%s"', p).strip()
                print(':path:', p, format_description)
                print(':mt:', mediatype)
                print


varname = re.compile('^\$[A-Z0-9a-z]+$')

def search_path(paths, ctx):
    """Yield directories. Process JSON-path references from list `paths`. """
    for root_dir in paths:
        if root_dir.startswith('#prefixes/'):
            # Process symbolic rc references
            prefref = root_dir[10:]
            if ':' in prefref:
                prefref, num = prefref.split(':')
                yield ctx.prefixes.map_[prefref][int(num)]
            else:
                for ref_root in search_path(ctx.prefixes.map_[prefref], ctx):
                    yield ref_root
        else:
            yield root_dir

def find_local(name, search):
    """
    Traverse prefixes in list `search`, yields where `name` exists.
    Yield load is tuple `prefix`, `full-file-path`, `full-dir-path`
    """
    for prefix in search:
        path = os.path.join(prefix, name)
        if os.path.exists(path):
            if os.path.isdir(path):
                return prefix, None, name
            else:
                return prefix, name, os.path.dirname(name) or '.'

def find_prefixes(path, ctx):
    for prefix, pathrefs in ctx.prefixes.map_.items():
        for prefpath in pathrefs:
            if path.startswith('#prefixes/'):
                prefref = prefpath[10:]
                prefpath = ctx.prefixes.map_[prefref]

        if path.startswith( prefpath ):
            yield prefix



def main(argv, doc=__doc__, usage=__usage__):

    """
    Execute using docopt-mpe options.

        prog [opts] [CTX] ( FILE... | DIR... )

    """

    # Process environment
    db = os.getenv( 'FINFO_DB', __db__ )
    if db is not __db__:
        usage = usage.replace(__db__, db)

    ctx = confparse.Values(dict(
        opts = libcmd_docopt.get_opts(doc + usage, version=get_version(), argv=argv[1:])
    ))
    ctx.opts.flags.dbref = taxus.ScriptMixin.assert_dbref(ctx.opts.flags.dbref)
    # Load configuration
    ctx.config_file = list(confparse.expand_config_path(ctx.opts.flags.config)).pop()
    ctx.settings = settings = confparse.load_path(ctx.config_file)
    # Load SA session
    ctx.sa = get_session(ctx.opts.flags.dbref)

    if ctx.opts.flags.show_info:
        print(ctx.opts.flags.dbref)
        print(ctx.config_file)
        return

    elif ctx.opts.flags.list:
        records = INode.all(sa=ctx.sa)
        # TODO: filter by prefix? INode.name.like("%%:%s" % name)).all()
        for record in records:
            print(record, record.date_updated, record.date_modified)
        return

    elif ctx.opts.flags.delete:
        records = INode.all((INode.name.like(ctx.opts.args.PATH),), sa=ctx.sa)
        for record in records:
            print(record, record.date_updated, record.date_modified)
            ctx.sa.delete(record)
        if not ctx.opts.flags.dry_run:
            ctx.sa.commit()
        return

    # DEBUG:
    #pprint(ctx.settings.todict())

    # Process arguments
    dirs = []
    # Shift paths from ctx arg
    if ctx.opts.args.CTX and os.path.exists(ctx.opts.args.CTX):
        ctx.opts.args.FILE.append(ctx.opts.args.CTX)
        ctx.opts.args.CTX = None

    # Sort out dirs from files
    for arg in ctx.opts.args.FILE:
        if os.path.isdir(arg):
            ctx.opts.args.FILE.remove(arg)
            dirs.append(arg)
        elif os.path.isfile(arg):
            pass
        else:
            log.note("Unhandled path %r" % arg)
    ctx.opts.args.DIR = dirs

    # Set default path context
    if ctx.opts.flags.name:
        assert not ctx.opts.args.CTX
        ctx.opts.args.CTX = ctx.opts.flags.name

    elif not ctx.opts.args.CTX:
        ctx.opts.args.CTX = 'current'


    # XXX: create prefixes object on context
    ctx.prefixes = confparse.Values(dict(
        map= settings.finfo['prefix-map'],
        env={},
        map_={}
    ))
    if 'homedir' not in ctx.prefixes.map:
        ctx.prefixes.map['homedir'] = 'HOME=%s' % os.path.expanduser('~')

    # TODO: check pwd, or args, fail on missing prefix-name
    if 'current' not in ctx.prefixes.map:
        ctx.prefixes.map['current'] = '$PWD:$HOME'
    if 'pwd' not in ctx.prefixes.map:
        ctx.prefixes.map['pwd'] = 'PWD=%s' % os.path.abspath('.')

    for prefix, path in ctx.prefixes.map.items():
        if '=' in path:
            envvar, path = path.split('=')
            if envvar in ctx.prefixes.env:
                assert ctx.prefixes.env[envvar] == prefix, (
                        ctx.prefixes.env[envvar], prefix )
            ctx.prefixes.env[envvar] = prefix



    # Pre-process binds from env flags

    if not isinstance(ctx.opts.flags.env, list):
        ctx.opts.flags.env = [ ctx.opts.flags.env ]

    for env_map in ctx.opts.flags.env:
        envvar, prefix = env_map.split('=')
        if envvar in ctx.prefixes.env:
            assert prefix == ctx.prefixes.env[envvar]
        else:
            ctx.prefixes.env[envvar] = prefix

        envvalue = os.getenv(envvar, None)
        if envvalue:
            ctx.prefixes.map[prefix] = "%s=%s" % ( envvar, envvalue )
            #ctx.prefixes.map_[prefix] = envvalue.split(':')

    # Post-process prefixes after passed flags, and resolve all values
    for prefix, spec in ctx.prefixes.map.items():
        if '=' in spec:
            envvar, spec = spec.split('=')
            if envvar in ctx.prefixes.env:
                assert ctx.prefixes.env[envvar] == prefix, (
                        ctx.prefixes.env[envvar], prefix )
            ctx.prefixes.env[envvar] = prefix

        specs = spec.split(':')
        set_ = []

        for idx, path in enumerate(specs):
            path = os.path.expanduser(path)
            if varname.match(path):
                refpref = ctx.prefixes.env[path[1:]]
                #refpath = ctx.prefixes.map[]
                path = '#prefixes/'+refpref

            elif '$' in path:
                pass
            #else:
            #    path = '#prefixes/'+prefix+':'+str(idx)

            set_.append(path)

        ctx.prefixes.map_[prefix] = set_

    ctx_name = ctx.opts.args.CTX
    if ctx_name not in ctx.prefixes.map_:
        raise Exception("No context '%s' among %s" % ( ctx_name,
            ctx.prefixes.map_.keys()))

    ctx.pathrefs = ctx.prefixes.map_[ctx.opts.args.CTX]

    #DEBUG:
    #print ctx.opts.todict()
    #print pformat(ctx.prefixes.todict())
    #print pformat(ctx.pathrefs)

    # Get filter arguments, order most significant first
    # Preprocess filter spec strings, compile to regex

    if 'INCLUDE' not in ctx.opts.args:
        ctx.opts.args.INCLUDE = []
    if 'INCLUDE_PATH' not in ctx.opts.args:
        ctx.opts.args.INCLUDE_PATH = []

    if not ctx.opts.args.INCLUDE:
        ctx.opts.args.INCLUDE = default_filters
    if ctx.opts.flags.documents:
        ctx.opts.args.INCLUDE = doc_filters + ctx.opts.args.INCLUDE
    for idx, filter in enumerate(ctx.opts.args.INCLUDE):
        if isinstance(filter, str):
            print('new filter', filter)
            ctx.opts.args.INCLUDE[idx] = fnmatch.translating(filter)

    # Resolve FILE/DIR arguments
    files, dirs = [], []
    for arg in ctx.opts.args.FILE + ctx.opts.args.DIR:
        r = find_local(arg, search_path(ctx.pathrefs, ctx))
        if not r: continue
        prefix, file, dir = r
        if not dir:
            raise Exception("No path for %s" % arg)
        elif file:
            files.append((prefix, file))
        else:
            dirs.append((prefix, dir))

    print("Resolved arguments to %s dirs, %s files" % ( len(dirs), len(files) ))

    # XXX: if not ctx.opts.flags.directories:

    if ctx.opts.flags.recurse:
        # Resolve all dirs to file lists
        for p, d in dirs:
            for top, path_dirs, path_files in os.walk(os.path.join(p, d)):
                for path_dir in list(path_dirs):
                    for filter in ctx.opts.args.INCLUDE_PATH:
                        if not filter.match(os.path.basename(path_dir)):
                            path_dirs.remove(path_dir)
                            break

                if top.startswith('./'):
                    top = top[2:]

                for path_file in list(path_files):
                    filter = None
                    for filter in ctx.opts.args.INCLUDE:
                        if filter.match(os.path.basename(path_file)):
                            break
                        else:
                            continue
                    if not filter.match(os.path.basename(path_file)):
                        path_files.remove(path_file)
                    if path_file not in path_files:
                        continue
                    files.append((p, os.path.join(top, path_file)))

    print("Continue with %s files" % len(files))

    mfadapter = None
    res.persistence.PersistedMetaObject.stores['metafile'] = mfadapter


    prefix = None
    for p, f in files:

        if ctx.opts.flags.auto_prefix:

            prefixes = find_prefixes(p, ctx)
            assert prefixes # FIXME: how come only use first??
            prefix = prefixes.next()
            assert len(ctx.prefixes.map_[prefix]) == 1, prefix
            name = f[len(ctx.prefixes.map_[prefix][0])+1:]

        else:
            prefix = ctx.opts.args.CTX
            name = f[len(p)+1:]

        ref = prefix+':'+name

        if ctx.opts.flags.names_only:
            print(ref)

        else:
            # TODO: get INode through context? Also add mediatype & parameters
            # resolver. But needs access to finfo ctx..

            records = ctx.sa.query(INode).filter(
                    INode.name.like("%%:%s" % name)).all()
            if not records:
                record = INode.get_instance(name=ref, _sa=ctx.sa,
                        _fetch=False)
            elif len(records) > 1:
                raise Exception("Multiple path ID matches %r" % name)
            else:
                record = records[0]

            # TODO: update existing
            mf = res.metafile.Metafile(f)
            #mediatype = lib.cmd('--mime "%s"', path).strip()
            # XXX: see basename-reg?

            assert mf.date_accessed
            record.date_accessed = mf.date_accessed
            assert mf.date_modified
            record.date_modified = mf.date_modified

            if not record.node_id:
                ctx.sa.add(record)
                print('new', record, record.date_updated, record.date_modified)
            else:
                print('new', record, record.date_updated, record.date_modified)

            if ctx.opts.flags.update:
                ctx.sa.commit()



def get_version():
    return 'finfo.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    sys.setrecursionlimit(100)
    base=os.path.basename(sys.argv[0])
    if base == 'finfo.py':
        sys.exit(main(sys.argv))
    elif base == 'finfo-app.py':
        app = FileInfoApp.main()
    else:
        raise Exception(base+'?')
