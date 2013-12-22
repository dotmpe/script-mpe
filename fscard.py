#!/usr/bin/env python
import hashlib
import os
from os.path import join, dirname, abspath, basename
import shelve
import sys
import time
import traceback

import lib
from res.fs import File, Dir, StatCache
from res.store import IndexedObject, Contents, Match, Content,\
        PathNode, sha1hash as key
import uuid


def normalize( rootdir, path, fnenc='ascii' ):
    if StatCache.isdir( path.encode( fnenc ) ):
        if not path.endswith( os.sep ):
            path += os.sep
    assert StatCache.isdir( rootdir.encode( fnenc ) )
    if not rootdir.endswith( os.sep ):
        rootdir += os.sep
    assert path.startswith( rootdir )
    path = path[ len( rootdir ): ]
    return path

def find_dir( dirpath, subleaf ):
    dirparts = dirpath.rstrip( os.sep ).split( os.sep )
    while dirparts:
        path = os.sep.join( dirparts )
        p = os.sep.join( tuple( dirparts )+( subleaf, ) )
        if StatCache.exists( p ) and StatCache.isdir( p ):
            return path + os.sep
        dirparts.pop()

def _do_run( path, voldir, size_threshold, size_threshold2, fnenc, f ):
    assert StatCache.getsize( f.encode( fnenc ) ) > size_threshold
    assert StatCache.getsize( f.encode( fnenc ) ) <= size_threshold2

    path = normalize( voldir, f, fnenc )
    assert isinstance( path, unicode )
    pathhash = key( path )
    assert not isinstance( pathhash, unicode )

    matches = []

    # Fetch or init a content descriptor
    content_guid = Contents.relates.record.left.find( pathhash )
    if not content_guid:
        content_guid = Contents.relates.record.new( pathhash, None )
        Contents.set( 'path', pathhash, path.encode( fnenc ) )
    else:
        print 'GUID', content_guid, 'exists'
        if not content_guid in Content.indices.paths.data:
            Content.indices.paths.data[ content_guid ] = []
        Content.indices.paths.data[ content_guid ] += [ pathhash ]
    assert content_guid and content_guid in Content.indices.paths.data
    assert pathhash in Content.indices.paths.data[ content_guid ]
    assert Content.indices.paths == Contents.relates.record.right
    assert Contents.relates.record.left.data[ pathhash ] == content_guid
    assert Contents.indices.path.data[ pathhash ] == path.encode( fnenc )
    print pathhash, ' -- ', content_guid

    # Clean up and abort on missing path
    if not StatCache.exists( f.encode( fnenc ) ):
        del Contents.indices.path.data[ pathhash ]
        del Contents.indices.record.data[ pathhash ]
        paths = Content.indices.paths.data[ content_guid ]
        paths.remove( pathhash )
        Content.indices.paths.data[ content_guid ] = paths
        print pathhash, "DEL ", path
        return

# FIXME: Content mtime
#        if content_guid not in Content.indices.time.data:
#            record_time = str( int( time.time() ) )
#            Content.indices.time.data[ content_guid ] = record_time
#        else:
#            record_time = int( round( float( Content.indices.time.data[ content_guid ] ) ))
#            if StatCache.getmtime( f.encode( fnenc ) ) <= record_time:
#                pass # ok
#            else:
#                Content.indices.time.data[ content_guid ] = \
#                        str( round( StatCache.getmtime( f.encode( fnenc ) ) ) )
#                print pathhash, ' -- ', record_time

# FIXME: proper init of size
    size = StatCache.getsize( f.encode( fnenc ) )
    if not Match.find( 'sizes', size ):
        Content.relates.size.new( content_guid, size )
        print pathhash, 'SIZE', size
    elif not Content.find( 'size', content_guid ):
        Content.relates.size.new( content_guid, size )
        print pathhash, 'SIZE', size
    assert content_guid in Content.indices.size.data
    cur_size = Content.indices.size.get( content_guid )
    assert cur_size == size,\
            "Error: %s SIZE: %r vs %r" % ( pathhash, size, cur_size )
    assert size in Match.indices.sizes
    assert content_guid in Match.indices.sizes.get( size )
    print pathhash, 'OK  ', lib.human_readable_bytesize( size ), len(
        Match.indices.sizes.get( size ) )

# FIXME: recognize dupes
    start = time.time()
    sparsesum = Match.init_sparsesum( f.encode( fnenc ) )    
    dt = time.time() - start
    if not Match.find( 'sparsesums', sparsesum ):
        Content.relates.sparsesum.new( content_guid, sparsesum )
        print content_guid, 'SPRS', sparsesum, \
                '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2) / dt )
        return True
    else:
        print sparsesum, Match.find( 'sparse', sparsesum )
        assert sparsesum in Match.indices.sparsesums.data
        if content_guid not in Match.indices.sparsesums.data[ sparsesum ]:
            print content_guid, "DUPE", lib.strlen( path, 96 )
            _dump_paths( sparsesum, 'sparsesums' )
            print content_guid, 'SPRS', sparsesum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2 ) / dt )
        else:
            return

#        start = time.time()
#        cksum = lib.get_checksum_sub( f.encode( fnenc ), 'ck' )
#        dt = time.time() - start
#        if not Match.find( 'ck', cksum ):
#            Match.indices.cksums.data[ cksum ] = [ content_guid ]
## TODO:            volume.indices.ck_cost.data[  ]
#            print content_guid, 'ck  ', cksum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2 ) / dt ) 
#        else:
#            if content_guid not in Match.indices.cksums.data[ cksum ]:
#                print "possible duplicate", strlen( f.encode( fnenc ), 96 )
#                curguid = Match.indices.cksums.data[ cksum ][0]
#                _dump_paths( curguid, 'cksums' )
#                print content_guid, 'CK  ', cksum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size
#                    / 1024 ** 2 ) / dt )
#                return

    start = time.time()
    sha1sum = lib.get_checksum_sub( f.encode( fnenc ) )
    dt = time.time() - start
    if not Match.find( 'sha1', sha1sum ):
        Match.indices.sha1sums.data[ sha1sum ] = [ content_guid ]
        print content_guid, 'sha1', sha1sum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size /
            1024 ** 2 ) / dt )
        return True
    else:
        if content_guid not in Match.indices.sha1sums.data[ sha1sum ]:
            #curguids = Match.indices.sha1sums.data[ sha1sum ]
            #if curguids:
            #    assert len( curguids ) == 1
            #else:
            #    return
            #curguid = curguids[0]
            #print content_guid, "DUPE", curguid, strlen( path, 96 )
            #pathhash_list = Content.indices.paths.data[ curguid ]
            #print 'pathhash_list', pathhash_list
            #if pathhash not in pathhash_list:
            #    pathhash_list.append( pathhash )
            #    ml = Match.indices.sha1sums.data[ sha1sum ]
            #    if content_guid in ml:
            #        ml.remove( content_guid )
            #        Match.indices.sha1sums.data[ sha1sum ] = ml
            #    del Content.indices.paths.data[ content_guid ] 
            #    if content_guid in Content.indices.descr.data:
            #        del Content.indices.descr.data[ content_guid ] 
            #    if content_guid in Content.indices.time.data:
            #        del Content.indices.time.data[ content_guid ] 
            #    content_guid = curguid
            #    Content.indices.paths.data[ content_guid ] = pathhash_list
            #print Match.indices.sha1sums.data[ sha1sum ]
            _dump_paths( sha1sum, 'sha1' )
            print content_guid, 'SHA1', sha1sum, '(%.2f s, %.4f Mb/s)' % ( dt , (
                size / 1024 ** 2 ) / dt )
        else:
            return

    start = time.time()
    md5sum = lib.get_checksum_sub( f.encode( fnenc ), 'md5' )
    dt = time.time() - start
    if not Match.find( 'md5', md5sum ):
        Match.indices.md5sums.data[ md5sum ] = [ content_guid ]
        print content_guid, 'md5 ', md5sum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2) / dt )
        return True
    else:
        if content_guid not in Match.indices.md5sums.data[ md5sum ]:
            print "possible duplicate", lib.strlen( f.encode( fnenc ), 96 )
            _dump_paths( md5sum, 'md5sums' )
            print content_guid, 'MD5 ', md5sum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2 ) / dt )
        else:
            return

    return True

def _dump_paths( key, index ):
    curguids = getattr( Match.indices, index ).data[ key ]
    updated = False
    for curguid in curguids:
        if curguid not in Content.indices.paths.data:
            print "GUID %s from index %s has no known paths" % ( curguid, index )
            curguids.remove( curguid )
            updated = True
    #                    assert curguid in Content.indices.record.data
        else:
            for x in Content.indices.paths.data[ curguid ]:
                print curguid, 'Content.paths', Contents.indices.path.data[ x ]
    if updated:
        getattr( Match.indices, index ).data[ key ] = curguids

def _do_cleanup( path, voldir, fnenc, f ):
    path = normalize( dirname( voldir ), f, fnenc )
    pathhash = key( path )
    assert not isinstance( pathhash, unicode )
    guid = None

    if Contents.find( 'path', pathhash ):
        del Contents.indices.path.data[ pathhash ]
    if Contents.find( 'record', pathhash ):
        del Contents.indices.record.data[ pathhash ]


class WalkCounter(dict):
    def __init__( self, path, file_threshold=1000 ):
        dict.__init__( self )
        self.keys = []
        self.last_total = 0
        self.file_threshold = file_threshold
        self.push( path )
    def is_sub( self, dirpath ):
        return dirpath.startswith( self.key )
    def is_parent( self, dirpath ):
        return self.key.startswith( dirpath )
    def is_neighbour( self, dirpath ):
        if dirpath and self.key:
            p = 0
            maxlen = max( ( len( dirpath ), len( self.key ) ) )
            while dirpath[:p] == self.key[:p]:
                p += 1
                if p == maxlen:
                    break
            p -= 1
            tails = ( dirpath[p:], self.key[p:] )
            return ( os.sep not in tails[0] ) and ( os.sep not in tails[1] )
    @property
    def total( self ):
        c = self.last_total
        for k in self.keys:
            c += self[ k ]
        return c
    @property
    def cnt( self ):
        return self[ self.key ]
    @property
    def key( self ):
        assert self.keys, self
        return self.keys[ -1 ]
    @property
    def level( self ):
        return len( self.keys )
    @property
    def name( self ):
        return basename( self.key )
    def push( self, fpath ):
        assert fpath not in self
        assert fpath not in self.keys
        self.keys.append( fpath )
        self[ self.key ] = 0
    def pop( self ):
        assert self.keys, self
        cnt = self.cnt
        del self[ self.key ]
        self.keys.pop()
        self[ self.key ] += cnt
    def count( self ):
        self[ self.key ] += 1
    @property
    def triggered( self ):
        return self.cnt > self.file_threshold
    def reset( self ):
        self.last_total += self.cnt
        self[ self.key ] = 0

def main( path, voldir ):
    size_threshold = 14 * ( 1024 ** 2 ) # 14MB: noise threshold
    size_threshold2 = 14 * ( 1024 ** 3 ) # 14GB: high bound for bad ideas
    fnenc = 'utf-8'
    st = time.time()
    w_opts = Dir.walk_opts
    w_opts.recurse = True
    # start counting at root
    counter = WalkCounter( path )
    def _size_threshold( path ):
        size = StatCache.getsize( path )
        if not size: 
            return
        if size > size_threshold2:
            print 'Skipping too large file for now', path, \
                    size/float(size_threshold2), 'k'
            return
        if size > size_threshold:
            return True
#        else:
#            print 'Skipping small noise', size/float(size_threshold), 'k'
    file_filters = [ _size_threshold ]
    dir_filters = [ PathNode.is_dirty ]
#    print 'Walking', path
    for f in Dir.walk( path, w_opts, ( file_filters, dir_filters ) ):
        ft = time.time()
        # walk top down, depth first
        fenc = f.encode( fnenc )

        if StatCache.isdir( fenc ):
            continue
            # FIXME: stat cache
            if not fenc[ -1 ] == os.sep:
                f += os.sep
            #print counter.level * '\t', counter.name, counter.total, counter.cnt
            if fenc == counter.key:
                pass
            else:
                if not counter.is_sub( fenc ):
#                    print "left", counter.key
                    if counter.triggered:
                        counter.reset()
                        PathNode.update_walk( f, fnenc )
#                        print 'reset', counter.total
                    counter.pop()
                if counter.is_sub( fenc ):
                    counter.push( fenc )
#                    print "enter", counter.key
            #print counter.level * '\t', counter.name, counter.total, counter.cnt
            continue

        counter.count()
        print "File", fenc, counter.total
        
        try:
            v = _do_run( path, voldir, size_threshold, size_threshold2, fnenc, f )
        except UnicodeDecodeError, e:
            traceback.print_exc()
            _do_cleanup( path, voldir, fnenc, f )
        except KeyboardInterrupt, e:
            _do_cleanup( path, voldir, fnenc, f )
            raise
        except Exception, e:
            traceback.print_exc()
            _do_cleanup( path, voldir, fnenc, f )
            raise

        rt = time.time() - st
        if v:
            print 'Content %i done (%2.f / %2.f s). ' % ( counter.total, time.time() - ft , rt )
            print
            v = False
        elif not counter.total % 1000:
            print "Content %s.. (%.2f s)" % ( counter.total, rt )

    return

    counter.pop()
    #print "left", counter.key
    if counter.triggered:
        counter.reset()
    #print "Finished", path, counter.keys, counter.total
    assert counter.keys
    #print "OK", path, counter.total

def main_full():
    argv = list( sys.argv )
    script_name = argv.pop(0)

    path = abspath( argv.pop() )

    #Volumes.init( userdir )
    voldir = find_dir( path, '.cllct' )
    #volguid = Volumes.find( 'record', voldir )
    #volume = Volume.load( volguid )

    print "Volume:", voldir
    assert voldir

    IndexedObject.init( voldir, PathNode, Contents, Content, Match )

    try:
        main( path, voldir )
    except KeyboardInterrupt, e:
        print 'Interrupted'
    except Exception, e:
        print
        print 'Program failure: '
        traceback.print_exc()

    IndexedObject.close()


if __name__ == '__main__':

    main_full()


