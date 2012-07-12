"""
See Resourcer.rst

- Builds upon cmdline.
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
from res import PersistedMetaObject, Metafile, Volume, Repo

from taxus import Node, SHA1Digest, MD5Digest


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


@Target.register(NS, 'userdir', 'cmd:options')
def rsr_userdir(prog=None, settings=None):
    userdir = os.path.expanduser(settings.rsr.lib.paths.userdir)
    yield Keywords(
        prog=dict(userdir=userdir))


@Target.register(NS, 'lib', 'rsr:userdir')
def rsr_lib(prog=None, settings=None):
    """
    Initialize shared object indices. 
    
    PersistedMetaObject sessions are kept in three types of directories.
    These correspond with the keys in rsr.lib.paths.
    Sessions are initialized from rsr.lib.sessions.

    Also one objects session for user and system.
    The current user session is also set as default session.

    options:
        - rsr.lib.paths.systemdir
        - rsr.lib.paths.userdir
        - rsr.lib.sessions
    """
    # Normally /var/lib/cllct
    sysdir = settings.rsr.lib.paths.systemdir
    sysdbpath = os.path.join(sysdir,
            settings.rsr.lib.name)
    # Normally ~/.cllct
    usrdbpath = os.path.join(prog.userdir,
            settings.rsr.lib.name)
    # Initialize shelves
    sysdb = PersistedMetaObject.get_store('system', sysdbpath)
    usrdb = PersistedMetaObject.get_store('user', usrdbpath)
    vdb = PersistedMetaObject.get_store('volumes', 
            os.path.expanduser(settings.rsr.lib.sessions.user_volumes))
    # XXX: 'default' is set to user-database
    assert usrdb == PersistedMetaObject.get_store('default', usrdbpath)
    yield Keywords(
        volumes=vdb,
        objects=confparse.Values(dict(
                system=sysdb,
                user=usrdb
            )),
        )


@Target.register(NS, 'pwd', 'cmd:options')
def rsr_pwd(prog=None, opts=None, settings=None):
    log.debug("{bblack}rsr{bwhite}:pwd{default}")
    path = os.getcwd()
    yield Keywords(prog=dict(pwd=path))


@Target.register(NS, 'init-volume', 'rsr:pwd', 'rsr:lib')
def rsr_init_volume(prog=None):
    log.debug("{bblack}rsr{bwhite}:init-volume{default}")
    #PersistedMetaObject.get_store('global')
    path = prog.pwd
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
        log.note("Created new volume database at %s", dbpath)
        db.close()



@Target.register(NS, 'volume', 'rsr:pwd', 'rsr:lib')
def rsr_volume(prog=None, opts=None):
    """
    Return the current volume. In --init mode, a volume is created
    in the current directory.
    """
    log.debug("{bblack}rsr{bwhite}:volume{default}")
    Volume.init()
    assert prog.pwd, prog.copy().keys()
    volume = Volume.find(prog.pwd)
    print 'volume=',volume
    #volume = Volume.find('volumes', 'pwd', prog.pwd)
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


@Target.register(NS, 'ls', 'rsr:volume')
def rsr_ls(volume=None, volumedb=None):
    """

    """
    cwd = os.getcwd();
    lnames = os.listdir(cwd)
    for name in lnames:
        path = os.path.join(cwd, name)
        metafile = Metafile(path)
        if not metafile.non_zero():
            print "------", path.replace(cwd, '.')
            continue
        #print metafile.data['Digest'], path.replace(cwd, '.')
    print
    print os.getcwd(), volume.path, len(lnames)


#@Target.register(NS, 'clean', 'cmd:options')
#def rsr_clean(volumedb=None):
#    log.debug("{bblack}rsr{bwhite}:clean{default}")
#    vlen = len(volumedb)
#    log.err("Rsr: Closing volumedb")
#    volumedb.close()
#    log.err("Rsr: Closed, %i keys", vlen)


@Target.register(NS, 'list-volume', 'rsr:volume', 'txs:session')
def rsr_list_volume(prog=None, volume=None, opts=None):
    for r in sa.query(Node).all():
        print r


@Target.register(NS, 'scan', 'rsr:volume')
def rsr_scan(prog=None, volume=None, opts=None):
    """
    Walk all files, gather metadata into metafile.
    """ 
    log.debug("{bblack}rsr{bwhite}:update-volume{default}")
    i = 0
    log.info("Walking %s", prog.pwd)
    for path in Metafile.walk(prog.pwd):
        log.debug("Found %s", path)
        i += 1
        metafile, metacache = Metafile(path), None
        #if opts.persist_meta 
            #if metafile.exists:
            #metafile.rebase(basedir)
        #metafile.basedir = 'media/application/metalink/'
        if metafile.has_metafile():
            log.err("Re-read persisted metafile for %s", metafile.path)
        metacache, metaupdate = None, None
        if metafile.key in volumedb:
            metacache = volumedb[metafile.key]
            log.info("Found cached metafile for %s", metafile.key)
            #metacmp = metafile.compare(metacache)
        if metacache and metafile.has_metafile():
            assert metacache == metafile, \
                    "Corrupted cache, or metafile was updated externally. "
        else:
            metafile = metacache
        if metafile.needs_update():
            log.note("Needs update %s", metafile.path)
            #log.note("Updating metafile for %s", metafile.path)
            #metaupdate = metafile.update()
        #if metafile.key not in volumedb:
        #    log.note("Writing %s to volumedb", metafile.key)
        #    volumedb[metafile.key] = metafile
        if not metafile.has_metafile() or metafile.updated:
            #if options.persist_meta:
            #    if metafile.non_zero:
            #        log.warn("Overwriting previous metafile at %s", metafile.path)
            #    metafile.write()
            for k in metafile.data:
                print '\t'+k+':', metafile.data[k]
            print '\tSize: ', lib.human_readable_bytesize(
                metafile.data['Content-Length'], suffix_as_separator=True)
        else:
            print '\tOK'
        yield metafile
    #volumedb.sync()


#@Target.register(NS, 'volume', 'rsr:shared-lib')
#def rsr_update_content(opts=None, sharedlib=None):
#    sharedlib.contents = PersistedMetaObject.get_store('default', 
#            opts.contentdbref)
#
#def rsr_count_volume_files(volumedb):
#    print len(volumedb.keys())

@Target.register(NS, 'repo-update', 'rsr:lib', 'rsr:pwd')
def rsr_repo_update(prog=None, objects=None, opts=None):
    i = 0
    for repo in Repo.walk(prog.pwd, max_depth=2):
        i += 1
        assert repo.rtype
        assert repo.path
        print repo.rtype, repo.path, 
        if repo.uri:
            print repo.uri
        else:
            print 

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

# XXX: Illustration of the kwd types by rsr
import zope.interface
from zope.interface import Attribute, implements
# rsr:volume<IVolume>
class IVolume(zope.interface.Interface):
    pass
    # rsr:volume


if __name__ == '__main__':

    TargetResolver().main(['rsr:status'])


