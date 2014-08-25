"""
"""
import os

from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, Date, Float, \
    create_engine
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker


SqlBase = declarative_base()
metadata = SqlBase.metadata

class AccountBalance(SqlBase):
    """
    Checkpoints.
    """
    __tablename__ = 'accbalance'
    balance_id = Column('id', Integer, primary_key=True)
    date = Column(Date) # XXX: related ot blaance
    account_id = Column(Integer, ForeignKey('accs.id'))
    balance = Column(Integer) # XXX: related ot blaance

class Account(SqlBase):
    """
    """
    __tablename__ = 'accs'

    account_id = Column('id', Integer, primary_key=True)
    balance = Column(Integer) # XXX: related ot blaance
    account_name = Column(String)
    # classifiers? to match transactions    
    account_number = Column(String, unique=True, nullable=True)
    account_type = Column(String, nullable=False)

    def __str__(self):
        return "[Account %r #%s %s]" % ( self.account_name, self.account_number,
                self.account_type)

class Year(SqlBase):
    """
    """
    __tablename__ = 'years'

    year_id = Column('id', Integer, primary_key=True)
    account_id = Column(Integer, ForeignKey('accs.id'), nullable=False)
    date = Column(Date)
    end_balance = Column(Float)
    prev_year = Column(Integer, ForeignKey('years.id'), nullable=True)
    next_year = Column(Integer, ForeignKey('years.id'), nullable=True)

class Month(SqlBase):
    """
    """
    __tablename__ = 'months'

    month = Column('id', Integer, primary_key=True)
    account_id = Column(Integer, ForeignKey('accs.id'), nullable=False)
    date = Column(Date)
    end_balance = Column(Float)
    prev_month = Column(Integer, ForeignKey('months.id'), nullable=True)
    next_month = Column(Integer, ForeignKey('months.id'), nullable=True)

class Mutation(SqlBase):
    """
    Temporary? table to hold mutations.
    """
    __tablename__ = 'muts'
    mut = Column('id', Integer, primary_key=True)
    from_account = Column(Integer, ForeignKey('accs.id'), nullable=False)
    to_account = Column(Integer, ForeignKey('accs.id'), nullable=False)
    category = Column(String, nullable=False)
    srcid = Column(String)
    amount = Column(Float)

def get_session(dbref, initialize=False):
    engine = create_engine(dbref)#, encoding='utf8')
    #engine.raw_connection().connection.text_factory = unicode
    if initialize:
        #log.info("Applying SQL DDL to DB %s ", dbref)
        SqlBase.metadata.create_all(engine)  # issue DDL create 
        print 'Updated myLedger schema'
    session = sessionmaker(bind=engine)()
    return session



