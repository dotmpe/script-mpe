from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.engine import Engine

import zope.interface

from script_mpe import log
import iface
import out


SqlBase = declarative_base()



@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    """
    XXX on connect, assume is SQLite and > 3.6.19 
    """
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

def get_session(dbref, initialize=False, metadata=SqlBase.metadata):
    engine = create_engine(dbref)#, encoding='utf8')
    #engine.raw_connection().connection.text_factory = unicode
    metadata.bind = engine
    if initialize:
        log.info("Applying SQL DDL to DB %s..", dbref)
        metadata.create_all()  # issue DDL create 
        log.note('Updated schema for %s to %s', dbref, 'X')
    session = sessionmaker(bind=engine)()
    return session
#   dbref='mysql://scrow-user:p98wa7txp9zx@sam/scrow'
#   engine = create_engine(dbref, encoding='utf8', convert_unicode=False)
#    engine = create_engine('sqlite:///test.sqlite')#, echo=True)

    #dbref = 'mysql://robin/taxus'
    #dbref = 'mysql://robin/taxus_o'

def configure_components():
    zope.interface.classImplements(str, iface.IPrimitive)
    zope.interface.classImplements(unicode, iface.IPrimitive)
    zope.interface.classImplements(int, iface.IPrimitive)
    #zope.interface.classImplements(dict, IPrimitive)
    zope.interface.classImplements(list, iface.IPrimitive)
    #zope.interface.classImplements(tuple, IPyTuple)

    from datetime import datetime
    zope.interface.classImplements(datetime, iface.IPrimitive)

    # register IFormatted adapters
    iface.registerAdapter(out.IDFormatter)
    #idem as registry.register([IID], IFormatted, '', IDFormatter), etc
    iface.registerAdapter(out.PrimitiveFormatter)

    iface.registerAdapter(out.NodeSetFormatter)
    iface.registerAdapter(out.NodeFormatter)
    
    iface.registry.register([iface.IPrimitive], iface.IFormatted, '', out.PrimitiveFormatter)

    # TODO iface.gsm.registerUtility( obj, iface.IReferenceResolver ) 
