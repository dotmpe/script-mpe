"""

TODO: categorize accounts.
XXX: prolly rewrite year/month to generic period, perhaps scrap accbalances
"""
import os
import re

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
    __tablename__ = 'accbalances'
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
    name = Column(String)
    # classifiers? to match transactions
    nl_p_number = Column(Integer, unique=True, nullable=True)
    nl_number = Column(Integer, unique=True, nullable=True)
    iban = Column(String, unique=True, nullable=True)

    account_type = Column('type', String)

    def __str__(self):
        return "[Account %r #%s %s]" % ( self.name, 
                self.iban or self.nl_number or self.nl_p_number,
                self.account_type)

    def set_nr(self, account_number):
        """
        XXX only valid for dutch acc nrs.
        """
        if valid_nl_p_number(account_number):
            self.nl_p_number = int(account_number[1:])
        elif valid_nl_number(account_number):
            self.nl_number = int(account_number)
        elif valid_iban(account_number):
            self.iban = account_number
        else:
            print 'Unknown account number:', account_number
            return False

    @classmethod
    def for_name_type(klass, session, name, account_type=None):
        """
        Return existing or create.
        """
        acc_rs = session.query(Account).filter(
                Account.account_type == account_type).filter(
                Account.name == name.strip()).all()
        if acc_rs:
            acc = acc_rs[0]
        else:
            acc = Account(name=name.strip(), account_type=account_type)
            session.add(acc)
            session.commit()
        return acc

    @classmethod
    def for_checkout(klass, session, descr):
        return klass.for_name_type(session, descr, "checkout")

    @classmethod
    def for_withdrawal(klass, session, descr):
        return klass.for_name_type(session, descr, "atm")

    @classmethod
    def for_nr(klass, session, account_number):
        """
        XXX only valid for dutch acc nrs.
        """
        if valid_nl_p_number(account_number):
            acc_rs = session.query(Account)\
                    .filter( Account.nl_p_number == int(account_number[1:]) ).all()
            if not acc_rs:
                acc_rs = session.query(Account)\
                        .filter( Account.iban.like('%'+account_number[1:])).all()
        elif valid_nl_number(account_number):
            acc_rs = session.query(Account)\
                .filter( Account.nl_number == int(account_number) ).all()
            if not acc_rs:
                acc_rs = session.query(Account)\
                        .filter( Account.iban.like('%'+account_number) ).all()
        elif valid_iban(account_number):
            acc_rs = session.query(Account)\
                .filter( Account.iban == account_number ).all()
            if not acc_rs:
                acc_rs = session.query(Account)\
                        .filter( Account.nl_number ==
                                int(account_number[-10:]) ).all()
            if not acc_rs:
                acc_rs = session.query(Account)\
                        .filter( Account.nl_p_number ==
                                int(account_number[-9:]) ).all()
        else:
            assert account_number
            print 'Unknown account number:', account_number
            return

        if len(acc_rs) == 1:
            return acc_rs[0]
        else:
            assert not acc_rs or len(acc_rs) == 0

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
    change = Column(Float)
    transactions = Column(Integer)
    end_balance = Column(Float)
    prev_month = Column(Integer, ForeignKey('months.id'), nullable=True)
    next_month = Column(Integer, ForeignKey('months.id'), nullable=True)

class Mutation(SqlBase):
    """
    Temporary? table to hold mutations.
    """
    __tablename__ = 'muts'
    mut_id = Column('id', Integer, primary_key=True)
    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)
    day = Column(Integer, nullable=False)
    from_account = Column(Integer, ForeignKey('accs.id'), nullable=False)
    to_account = Column(Integer, ForeignKey('accs.id'), nullable=False)
    category = Column(String, nullable=False)
    description = Column(Text)
    amount = Column(Float)


models = [
        AccountBalance,
        Account,
        Year,
        Month,
        Mutation
    ]


def get_session(dbref, initialize=False):
    engine = create_engine(dbref)
    SqlBase.metadata.bind = engine
    if initialize:
        SqlBase.metadata.create_all()  # issue DDL create 
        print 'Updated myLedger schema'
    session = sessionmaker(bind=engine)()
    return session


# TODO: lookup checksum methods for acc nrs
def valid_iban(acc):
    return re.match('^[A-Z]{2}[0-9]{2}[A-Z]{4}[0-9]{10}$', acc)

def valid_nl_number(acc):
    return re.match('^[0-9]{9,10}$', acc)

def valid_nl_p_number(acc):
    return re.match('^P[0-9]{7,9}$', acc)



