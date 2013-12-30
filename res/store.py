"""

"""
import os
import sys
from os.path import join, expanduser, dirname
import anydbm
import hashlib
import shelve
import uuid

import lib
import confparse
from res.fs import Dir, StatCache


def sha1hash( obj ):
    assert isinstance( obj, basestring ), repr(obj)
    return hashlib.sha1( obj.encode( 'utf-8' ) ).hexdigest()

pathhash = sha1hash


### Field types

class Index:

    def __contains__( self, key ):
        return str( key ) in self.data

    def set( self, key, data ):
        self.data[ str( key ) ] = str( data )

    def get( self, key ):
        return self._tp( self.data[ str( key ) ] )
    
    def find( self, key ):
        if key in self:
            return self.get( str( key ) )

class Value( Index ):

    " obj.class.index[ key ] -- value "

    def __init__( self, klass, attr, path, _type=str ):
        self.klass = klass
        self.attr = attr
        self.data = lib.get_index( path )
        self._tp = _type

class Int( Value ):
    def __init__( self, klass, attr, path ):
        Value.__init__( self, klass, attr, path, _type=int )

class Float( Value ):
    def __init__( self, klass, attr, path ):
        Value.__init__( self, klass, attr, path, _type=float )

class ListValue( Index ):

    " obj.class.index[ key ] -- [ value1, ] "

    def __init__( self, klass, attr, path ):
        self.klass = klass
        self.attr = attr
        #print 'shelve open', path
        self.data = shelve.open( path )
        self._tp = list

    def get( self, key ):
        return self.data[ str( key ) ]

    def set( self ) :pass

    def append( self, key, data ):
        if str( key ) not in self.data:
            self.data[ str( key ) ] = [ ]
        if str( data) in self.data[ str( key ) ]:
            raise Exception("Duplicate value %s %r " % ( self,key) )
        self.data[ str( key ) ] += [ str( data ) ]

### Relations between two fields
class Relation:

    def __init__( self, idx_left, idx_right ):
        self.left = idx_left
        self.right = idx_right

class OneToOne_TwoWay( Relation ):

    " left_id    --  right_id"
    " right_id   --  left_id "

    " IndexLeft.relate_field = right_id "
    " IndexRight.relate_field = left_id "

class OneToMany( Relation ):

    " left_id    -*  right_id"

    " IndexLeft.relate_field = right_id"

class OneToMany_TwoWay( OneToMany ):

    " left_id    -*  right_id"
    " right_id   *-  left_id "

    " IndexLeft.relate_field = right_id "
    " IndexRight.relate_field = *left_id "

    def new( self, left_id, right_id ):
        if right_id == None:
            assert self.right.klass.key_type == 'guid'
            right_id = str( uuid.uuid4() )
        # set left (single) side
        self.left.set( left_id, right_id )
        # set right (many) side
        self.right.append( right_id, left_id )
        return right_id

### Base class for object types
class IndexedObject:

    """
     keyidx[ key ] = keyvalue
     valueidx[ keyvalue ] = IndexedObject(
        idx[ key ] => keytype( key ) / value
     )
    """

    index_spec = ()
    relate_spec = ()

    indices = None
    stores = None
    relates = None

    def __init__( self, key, value ):
        pass
#        clss = self.__class__
#        clss.default[  ]
#        IndexedObject.stores

    @staticmethod
    def init( voldir, *classes ):
        for clss in classes:
            clss.init_class( voldir )
        for clss in classes:
            clss.init_relations()

    @classmethod
    def init_class( clss, voldir ):
        clss.indices = confparse.Values({})
        if not IndexedObject.stores:
            IndexedObject.stores = confparse.Values({})
        if not Dir.issysdir( voldir ):
            vol = join( voldir, ".cllct" )
        else:
            vol = voldir
            voldir = dirname( vol.rstrip( os.sep ) )
        for idx in clss.index_spec:
            attr_name, idx_class = idx[ : 2 ]
            cn = clss.__name__
            # XXX: this would depend on direction (if expanding index facade)
            store_name = "%s_%s"%( cn, attr_name ) 
            #print 'init', store_name
            index = idx_class( clss, attr_name, join( vol, "%s.db" % store_name ) )
            # XXX
            setattr( IndexedObject.stores, store_name, index )
#            if len( idx ) == 4:
#                rev_class, rev_attr = idx[ 2 : ]
#                index = idx_class( 
#                        klass1, attr_name, join( voldir, "%s.db" % attr_name),
#                        klass2, rev_attr, join( voldir, "%s.db" % rev_attr ) )
            setattr( clss.indices, attr_name, index )

    @classmethod
    def init_relations( clss ):
        ## Init relations
        if not IndexedObject.relates:
            IndexedObject.relates = confparse.Values({})
        for field, rtype, rfield, relate_class in clss.relate_spec:
            left_idx = getattr( clss.indices, field )
            mod = sys.modules[ clss.__module__ ]
            rclass = getattr( mod, rtype )
            right_idx = getattr( rclass.indices, rfield )
            relate = relate_class( left_idx, right_idx )
            setattr( clss.relates, field, relate )

    @classmethod
    def default( clss ):
        return clss.indices[ clss.key ]

    @classmethod
    def find( clss, *args ):
        if len(args) == 1:
            args = ( clss.key, )+ args
            return clss.find( *args )
        idx, key = args
        if idx not in clss.indices:
            return
        return clss.indices[ idx ].find( key )
        return idx.find( key )

    @classmethod
    def fetch( clss, idx, key ):
        v = clss.find( idx, key )
        if not v:
            raise KeyError, "No such item %s.%s [ %s ] " % ( clss.__name__, idx, key )
        return v

    # XXX: new code
    @classmethod
    def load( clss, idx, key ):
        v = clss.fetch( idx, key )
        return clss( v )
    # /xxx

    @classmethod
    def set( clss, idx, key, value ):
        assert idx in clss.indices
        clss.indices[ idx ].data[ key ] = value

    @classmethod
    def get_relate( clss, idx, key, value ):
        pass

    @classmethod
    def find_relate( clss, idx, key, value ):
        pass

# XXX
#    @classmethod
#    def add_relate( clss, idx, this, other ):
#        if not value:
#            if clss.keytype == 'guid':
#                value = str( uuid.uuid4() )
#        if clss.keytype == 'pathhash':
#            value = pathhash( value )
#        clss.set( idx, idx, this )

    @classmethod
    def close( clss ):
        for idx in clss.stores:
            clss.stores[ idx ].data.close()
            print 'Closed', idx

### 

class Volumes( IndexedObject ):
    """
    Just for the rootdir.

    Volume.vpath (~/.cllct/volumes.db)::
        pathhash      --  voldir
    Volume.record
        pathhash      --  guid
    """
    index_spec = (
            ( 'vpath', Value ),
            ( 'record', Value ),
    )
    key_type = 'pathhash'

class Volume( IndexedObject ):
    """
    Just for the rootdir.

    Volume.ck_cost
        guid          --  0.2
    Volume.size
        guid          --  112 bytes (file contents; actual data)
    Volume.fs_size
        guid          --  11 bytes (file meta; inode structure)
    Volume.sys_size
        guid          --  000 bytes (system files; classified non-user data)

    Volume.space_used
        guid          --  321 bytes (from blocks; size + fs meta)
    Volume.space_available
        guid          --  123 bytes (from blocks)
    Volume.space_usage
        guid          --  66.67%
    """
    index_spec = (
#            ( 'vpath', Value ),
# because we do not know where the volume is located physically,
# we keep a locally recorded avg cost in  sec / GB
            ( 'ck_cost', Float ),
            ( 'sha1_cost', Float ),
            ( 'md5_cost', Float ),
        )
    #key = 'Volumes.vpath' [ Volumes.key ] = self.key_type( self.key )
    key_type = 'guid'

class PathNode( IndexedObject ):
    """
    Metadata for large folders. 
    path::

        <pathhash>  --  <path>

    descr::
    
        <pathhash>  --  <descr>

    time::
    
        <pathhash>  --  <timestamp>
    """
    index_spec = (
            ( 'path', Value ),
            ( 'time', Value ),
            ( 'size', Int ), # TODO: integrate
        )
    key_type = 'guid'
    @classmethod
    def is_dirty( clss, path ):
        "True for either new or update"
        path = StatCache.init( path )
        assert isinstance( path, unicode )
        pathhash = sha1hash( path )
        if pathhash in PathNode.indices.time.data:
            record_time = int( round( float( PathNode.indices.time.data[ pathhash ] ) ))
            if StatCache.getmtime( f.encode( fnenc ) ) <= record_time:
                return False
            else:
                PathNode.indices.time.data[ pathhash ] = \
                        str( round( StatCache.getmtime( f.encode( fnenc ) ) ) )
                print pathhash, ' -- ', record_time
        return True
    @classmethod
    def init_record( clss, path ):
        path = StatCache.init( path )
        assert isinstance( path, unicode )
        pathhash = sha1hash( path )
        fnenc = 'utf-8'
        if not clss.find( 'path', pathhash ):
            clss.indices.path.data[ pathhash ] = path.encode( fnenc )
            #assert pathhash in Content.indices.paths.data[ pathhash ]
            print pathhash, 'NEW ', lib.strlen( clss.indices.path.data[ pathhash ], 96 )
        else:
            path = clss.indices.record.data[ pathhash ].decode( fnenc )
    @classmethod
    def update_walk( clss, path, fnenc ):
        path = StatCache.init( path )
        assert isinstance( path, unicode )
        pathhash = sha1hash( path )
        if pathhash not in PathNode.indices.time.data:
            clss.init_record( path )
            record_time = str( int( time.time() ) )
            PathNode.indices.time.data[ pathhash ] = record_time
            return True
        else:
            record_time = int( round( float( PathNode.indices.time.data[ pathhash ] ) ))
            if StatCache.getmtime( path.encode( fnenc ) ) <= record_time:
                return False
            else:
                PathNode.indices.time.data[ pathhash ] = \
                        str( round( StatCache.getmtime( path.encode( fnenc ) ) ) )
                print pathhash, ' -- ', record_time
                return True

class Contents( IndexedObject ):
    """
    For known files.

    path (.volume/Contents_path.db)::

        <pathhash>  --  <path>

    record (.volume/Contents_record.db)::

        <pathhash>  *-  <guid>
    """
    index_spec = (
            ( 'path', Value ),
            ( 'record', Value ),
#           ( 'record', Content.guid )
        )
    key = 'path'
    key_type = 'pathhash'
    relate_spec = (
            ( 'record', 'Content', 'paths', OneToMany_TwoWay ),
        )

class Content( IndexedObject ):
    """
    paths (.volume/Path_paths.db)::
    
        <guid>   -*   <pathhash>

    descr (card.db)::
    
        <guid>  --  <descr>

    time (card-timestamp.db)::
    
        <guid>  --  <timestamp>
    """
    index_spec = (
            ( 'paths', ListValue, ),
#           ( 'paths', list(Contents.path) )
            ( 'descr', Value ),
            ( 'mtime', Int ),
            ( 'size', Int ),
            ( 'sha1sum', Value ),
            ( 'md5sum', Value ),
            ( 'cksum', Value ),
            ( 'sparsesum', Value ),
        )
    id_field = None
    key_type = 'guid'
    relate_spec  = (
            ( 'size', 'Match', 'sizes', OneToMany_TwoWay ),
            ( 'sparsesum', 'Match', 'sparsesums', OneToMany_TwoWay ),
            ( 'sha1sum', 'Match', 'sha1sums', OneToMany_TwoWay ),
            ( 'cksum', 'Match', 'cksums', OneToMany_TwoWay ),
            ( 'md5sum', 'Match', 'md5sums', OneToMany_TwoWay ),
        )

class Match( IndexedObject ):
    """
    .volume/<hashtype>.db

        <contenthash>  -*  <guid>

    # find list of possible guids
    .volume/first20.db        first20bytes  =*  guid
    .volume/sha1.db           sha1sum       =*  guid
    """
    index_spec = (
#            ( 'first20', ListValue, ), XXX: need new heuristic, must be faster than cksum
            ( 'sizes', ListValue, ),
            ( 'sparsesums', ListValue, ),
            ( 'cksums', ListValue, ),
            ( 'sha1sums', ListValue, ),
            ( 'md5sums', ListValue, ),
    )

    # custom local methods
    @classmethod
    def init_sparsesum( clss, filepath ):
        sparsesum = hashlib.sha1( 
                    lib.get_sparsesig( 128, filepath )
                ).hexdigest()
        return sparsesum
