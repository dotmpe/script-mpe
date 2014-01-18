from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import log


SqlBase = declarative_base()




def get_session(dbref, initialize=False):
    engine = create_engine(dbref)#, encoding='utf8')
    #engine.raw_connection().connection.text_factory = unicode
    if initialize:
        log.info("Applying SQL DDL to DB %s..", dbref)
        SqlBase.metadata.create_all(engine)  # issue DDL create 
        log.note('Updated schema for %s to %s', dbref, 'X')
    session = sessionmaker(bind=engine)()
    return session
#   dbref='mysql://scrow-user:p98wa7txp9zx@sam/scrow'
#   engine = create_engine(dbref, encoding='utf8', convert_unicode=False)
#    engine = create_engine('sqlite:///test.sqlite')#, echo=True)

    #dbref = 'mysql://robin/taxus'
    #dbref = 'mysql://robin/taxus_o'


