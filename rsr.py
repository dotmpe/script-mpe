"""
See Resourcer.rst
"""
import os
import shelve
from pprint import pformat

import lib
import log
import confparse
from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
    Target 
from res import PersistedMetaObject, Metafile, Volume



NS = Namespace.register(
        prefix='rsr',
        uriref='http://project.dotmpe.com/script/#/cmdline.Resourcer'
    )

Options.register(NS, 

        (('-F', '--output-file'), { 'metavar':'NAME', 
            'default': None, 
            'dest': 'outputfile',
            }),

        (('-R', '--recurse', '--recursive'),{ 
            'dest': "recurse",
            'default': False,
            'action': 'store_true',
            'help': "For directory listings, do not descend into "
            "subdirectories by default. "
            }),

        (('-L', '--max-depth', '--maxdepth'),{ 
            'dest': "max_depth",
            'default': -1,
            'help': "Recurse in as many sublevels as given. This may be "
            " set in addition to 'recurse'. 0 is not recursing and -1 "
            "means no maximum level. "
            })

    )



#def rsr_workspace(opts=None):
#    pass # determine, init dir
#

@Target.register(NS, 'shared-lib', 'cmd:options')
def rsr_shared_lib(prog=None):
    libs = confparse.Values(dict(
            path='/usr/lib/cllct',
        ))
    prog.update(dict(sharedlib=libs))
    yield Keywords(sharedlib=libs)
    yield libs

@Target.register(NS, 'init-volume', 'txs:pwd', 'rsr:shared-lib')
def rsr_init_volume():
    #PersistedMetaObject.get_store('global')
    path = os.getcwd()
    #Volume.create(path)
    cdir = os.path.join(path, '.cllct')
    if not os.path.exists(cdir):
        os.mkdir(cdir)
    dbpath = os.path.join(cdir, 'volume.db')
    if os.path.exists(dbpath):
        log.err("DB exists at %s", dbpath)
    else:
        db = shelve.open(dbpath)
        #DB_MODE = 'n'
        #db = anydbm.open(dbpath, DB_MODE)
        db['mounts'] = [path]
        log.info("Created new volume database %s", dbpath)
        db.close()

@Target.register(NS, 'volume', 'rsr:shared-lib')
def rsr_volume(prog=None, opts=None):
    log.debug("{bblack}rsr{bwhite}:volume{default}")
    volume = Volume.find(prog.pwd)
    if not volume:
        if opts.init:
            name = Name.fetch('rsr:init-volume')
            assert name, name
            yield Targets('rsr:init-volume',)
        else:
            log.err("Not in a volume")
            yield 1
    else:
        log.note("rsr:volume %r for %s", volume.db, volume.full_path)
        yield Keywords(volume=volume)
        volumedb = PersistedMetaObject.get_store('volume', volume.db)
        log.info("rsr:volume index length: %i", len(volumedb))
        yield Keywords(volumedb=volumedb)
    #Metafile.default_extension = '.meta'
    #Metafile.basedir = 'media/application/metalink/'


#@Target.register(NS, 'clean', 'cmd:options')
#def rsr_clean(volumedb=None):
#    log.debug("{bblack}rsr{bwhite}:clean{default}")
#    vlen = len(volumedb)
#    log.err("Rsr: Closing volumedb")
#    volumedb.close()
#    log.err("Rsr: Closed, %i keys", vlen)


@Target.register(NS, 'update-volume', 'rsr:volume')
def rsr_update_volume(prog=None, volume=None, volumedb=None, opts=None):
    """
    Walk all files, gather metadata into metafile.

    Create metafile if needed. Fill in 
        - X-First-Seen
    This and every following update also write:
        - X-Last-Update
        - X-Meta-Checksum
    Metafile is reloaded when
        - Metafile modification exceeds X-Last-Update
    Updates of all fields are done when:
        - File modification exceeds X-Last-Modified
        - File size does not match Length
        - If any of above mentioned and at least one Digest field is not present.

    """ 
    log.debug("{bblack}rsr{bwhite}:update-volume{default}")
    i = 0
    for path in Metafile.walk(prog.pwd):
        print path
        i += 1
        new, updated = False, False
        metafile = Metafile(path)
        #if options:
        #metafile.basedir = 'media/application/metalink/'
        #if metafile.key in volumedb:
        #    metafile = volumedb[metafile.key]
        #    #log.err("Found %s in volumedb", metafile.key)
        #else:
        #    new = True
        if metafile.needs_update():
            log.err("Updating metafile for %s", metafile.path)
            metafile.update()
            updated = True
        #if updated or metafile.key not in volumedb:
        #    log.err("Writing %s to volumedb", metafile.key)
        #    volumedb[metafile.key] = metafile
        #    new = True
        if new or updated:
            #if options.persist_meta:
            #if metafile.non_zero:
            #    log.err("Overwriting previous metafile at %s", metafile.path)
            metafile.write()
            for k in metafile.data:
                print '\t'+k+':', metafile.data[k]
            print '\tSize: ', lib.human_readable_bytesize(
                metafile.data['Content-Length'], suffix_as_separator=True)
        else:
            print '\tOK'

    volumedb.sync()


#@Target.register(NS, 'ls', 'rsr:volume')
#def rsr_ls(volume=None, volumedb=None):
#    cwd = os.getcwd();
#    lnames = os.listdir(cwd)
#    for name in lnames:
#        path = os.path.join(cwd, name)
#        metafile = Metafile(path)
#        if not metafile.non_zero():
#            print "------", path.replace(cwd, '.')
#            continue
#        print metafile.data['Digest'], path.replace(cwd, '.')
#    print
#    print os.getcwd(), volume.path, len(lnames)
#
#
#@Target.register(NS, 'volume', 'rsr:shared-lib')
#def rsr_update_content(opts=None, sharedlib=None):
#    sharedlib.contents = PersistedMetaObject.get_store('default', 
#            opts.contentdbref)
#
#def rsr_count_volume_files(volumedb):
#    print len(volumedb.keys())
#
#def rsr_repo_update(self, options=None):
#    pwd = os.getcwd()
#    i = 0
#    for path in Repo.walk(pwd, max_depth=2):
#        i += 1
#        print i,path
#
#@Target.register(NS, 'list-checksums', 'rsr:volume')
#def rsr_list_checksums(volume=None, volumedb=None):
#    i = 0
#    for i, p in enumerate(volumedb):
#        print p
#    print i, 'total', volume.path
#
#def rsr_content_20(opts=None):
#    pass # load index
#
#def rsr_content_sha1(opts=None):
#    pass # load index
#
#def rsr_list_nodes(self, **kwds):
#    print self.session.query(Node).all()
#
#def rsr_import_bookmarks(self):
#    """
#    Import from
#      - HTML
#      - Legacy delicious XML
#    """
#    print self.session
#
#def rsr_dump_bookmarks(self):
#    pass
#
