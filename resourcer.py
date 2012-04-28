"""
"""
import lib
from target import Target, AbstractTargetResolver
from cmdline import err, Command
from res import Volume
from res import PersistedMetaObject, Metafile


class Resourcer(Command, AbstractTargetResolver):

    namespace = 'rsr', 'http://project.dotmpe.com/script/#/cmdline.Resourcer'

    handlers = [
            'cmd:options'
        ]
    depends = {
            'rsr:volume': [],
            'rsr:update-volume': ['rsr:volume'],
            'rsr:shared-lib': ['rsr:volume'],
            'rsr:update-content': ['rsr:shared-lib'],
        }

    def rsr_shared_lib(self, volume=None):
        libs = confparse.Value(dict(
            path='/usr/lib/cllct',
            ))
        yield dict(sharedlib=libs)

    def rsr_objects(self, opts=None, sharedlib=None):
        """
        Initialize default object store (for rsr.res)
        """
        sharedlib.objects = PersistedMetaObject.get_store('default', 
                opts.objectdbref)

    def rsr_content(self, opts=None, sharedlib=None):
        sharedlib.contents = PersistedMetaObject.get_store('default', 
                opts.contentdbref)

    def rsr_volume(self, prog=None, opts=None):
        volume = Volume.find(prog.pwd)
        if not volume:
            err("Not in a volume")
            yield 1
        err("rsr:volume %r", volume)
        yield dict(volume=volume)
        volumedb = PersistedMetaObject.get_store('volume', volume.db)
        err("rsr:volume index %i", len(volumedb))
        yield dict(volumedb=volumedb)
        #Metafile.default_extension = '.meta'
        #Metafile.basedir = 'media/application/metalink/'

    def rsr_content_20(self, opts=None):
        pass # load index

    def rsr_content_sha1(self, opts=None):
        pass # load index
        
    def rsr_clean(self, volumedb=None):
        vlen = len(volumedb)
        err("Rsr: Closing volumedb")
        volumedb.close()
        err("Rsr: Closed, %i keys", vlen)

    def rsr_update_volume(self, prog=None, volume=None, volumedb=None, opts=None):
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
            #    #err("Found %s in volumedb", metafile.key)
            #else:
            #    new = True
            if metafile.needs_update():
                err("Updating metafile for %s", metafile.path)
                metafile.update()
                updated = True
            #if updated or metafile.key not in volumedb:
            #    err("Writing %s to volumedb", metafile.key)
            #    volumedb[metafile.key] = metafile
            #    new = True
            if new or updated:
                #if options.persist_meta:
                #if metafile.non_zero:
                #    err("Overwriting previous metafile at %s", metafile.path)
                metafile.write()
                for k in metafile.data:
                    print '\t'+k+':', metafile.data[k]
                print '\tSize: ', lib.human_readable_bytesize(
                    metafile.data['Content-Length'], suffix_as_separator=True)
            else:
                print '\tOK'

        volumedb.sync()

lib.namespaces.update((Resourcer.namespace,))
Target.register(Resourcer)


if __name__ == '__main__':
    Resourcer().main()

