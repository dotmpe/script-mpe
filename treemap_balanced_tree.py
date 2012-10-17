"""

Filetree prototype: store paths in balanced, traversable tree structure 
for easy, fast and space efficient
index trees of filesystem (and other hierarchical structrures).

Introduction
______________________________________________________________________________
Why? Because filepath operations on the OS are generally far more optimized
than native code, only for extended sets some way of parallel (caching) 
structure may optimize performance. However since filesystem hierarchies are 
not balanced we want to make it balanced and avoid copying (parts) of the 
unbalanced index.

Without this, trying to use naive caches for run-time filesystem data may put 
a drag instead of a boost on performance. Obviously, to really optimize 
performance, the complete heuristics depend on the characteristics of the 
indexed data. The index only assures access balanced. The amount and 
contents of nodes is left to the utilizer of the Balanced Storage api.

Implementation
______________________________________________________________________________
Below is the code where Node implements the interface to the stored data,
and a separate Key implementation specifies the index properties of it.
Volume is the general session API which is a bit immature, but does store
and reload objects. Storage itself is a simple anydb with json encoded data.
"""
from hashlib import sha1

from treemap import FSWrapper


class BalancedStorage:

    ROOT = sha1( os.sep ).hexdigest()

    def __init__( self, volumedirpath ):
        self.path = FSWrapper( volumedirpath )

    @classmethod
    def fetch( clss, k, s=None ):
        return clss.instance.fetch( k, s=s )

    @classmethod
    def root( clss, s=None ):
        clss.fetch( clss.ROOT, s=s )

    # XXX: Single instance prototype
    instance = None
    @classmethod
    def init( clss, dirpath ): # s='default'
        clss.instance = clss( dirpath )
        
    # XXX: multiple sessions?
    @classmethod
    def vopen( clss, s='default' ):
        assert False
        

class FSKey:

    def __init__( self, node ):
        self.node = node

class Node:
        
    key_type = FSKey

    def __init__( self ):
        self.key_type = key_type

    @classmethod
    def load_from_storage( clss, key ):
        if not isinstance( key, clss.key_type )

"A session manager for a particular volume storage. "
#XXX: session = Volume.vopen( '/Volume/test-1' )
Volume.init( '/Volume/test-1' )

root = Volume.root()


