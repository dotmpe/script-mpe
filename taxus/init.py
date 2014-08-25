from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import zope.interface

from script_mpe import log
import iface
import out


SqlBase = declarative_base()


def get_session(dbref, initialize=False):
    engine = create_engine(dbref)#, encoding='utf8')
    #engine.raw_connection().connection.text_factory = unicode
    if initialize:
        log.info("Applying SQL DDL to DB %s..", dbref)
        SqlBase.metadata.create_all(engine)  # issue DDL create 
        log.note('Updated schema for %s to %s', dbref, 'X')
    SqlBase.metadata.bind = engine
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
