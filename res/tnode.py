class TreeNodeDict(dict):
    """
    Interface on top of normal dictionary to work easily with tree nodes
    which can have a name, attributes, and a value list.
    """

    def __init__(self, name):
        self[name] = None

    def getname(self):
        for key in self:
            if not key.startswith('@'):
                return key

    def setname( self, name ):
        oldname = self.getname()
        val = self[ oldname ]
        del self[ oldname ]
        self[ name ] = val

    name = property( getname, setname )
    "Node.name is a property or '@'-prefix attribute name. "

    def append( self, val ):
        "Node().value append"
        if not isinstance( self.value, list ):
            self[ self.name ] = []
        self.value.append( val )

    def remove( self, val ):
        "self item remove"
        self[ self.name ].remove( val )

    def getvalue( self ):
        "self item return"
        return self[ self.name ]

    value = property( getvalue )
    "Node.value is a list of subnode instances. "

    def getattrs( self ):
        attrs = {}
        for key in self:
            if key.startswith( '@' ):
                attrs[ key[ 1: ] ] = self[ key ]
        return attrs

    attributes = property( getattrs )

    def __getattr__( self, name ):
        # @xxx: won't properties show up in __dict__?
        if name in self.__dict__ or name in ( 'name', 'value', 'attributes' ):
            return super( Node, self ).__getattr__( name )
        elif '@' + name in self:
            return self[ '@' + name ]

    def __setattr__( self, name, value ):
        if name in self.__dict__ or name in ( 'name', 'value', 'attributes' ):
            super( Node, self ).__setattr__( name, value )
        else:
            self[ '@' + name ] = value

#    def __repr__(self):
#        return "<%s%s%s>" % ( self.name, self.attributes, self.value or '' )





