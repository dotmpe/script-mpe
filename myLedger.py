"""
TODO: categorize accounts.
XXX: prolly rewrite year/month to generic period, perhaps scrap accbalances
"""
import os
import re
from datetime import datetime

from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, Date, Float, \
    create_engine, func
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

from taxus.util import ORMMixin


SqlBase = declarative_base()
metadata = SqlBase.metadata



ACCOUNT_CREDIT = "Account:Credit"
ACCOUNT_EXPENSES = "Expenses"
ACCOUNT_ACCOUNTING = "Expenses:Account"

class Account(SqlBase, ORMMixin):

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

    date_added = Column(DateTime, index=True, nullable=False)
    last_updated = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)

    def init_defaults(self):
        if not self.date_added:
            self.last_updated = self.date_added = datetime.now()
        elif not self.last_updated:
            self.last_updated = datetime.now()

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
            acc.init_defaults()
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

    def __str__(self):
        x = []
        for p in "mut_id year month day amount from_account to_account category description".split(' '):
            x.append(getattr(self, p))
        return " ".join(map(str,x))

models = [
        Account,
        Mutation
    ]


def get_session(dbref, initialize=False, metadata=SqlBase.metadata):
    engine = create_engine(dbref)
    metadata.bind = engine
    if initialize:
        metadata.create_all()  # issue DDL create 
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

def fetch_expense_balance(settings, sa=None):
    "Return expence accounts and cumulative balance. "
    if not sa:
        sa = get_session(settings.dbref)
    expenses_acc = Account.all((Account.name.like(ACCOUNT_CREDIT+'%'),), sa=sa)
    balance, = sa.query(func.sum(Mutation.amount))\
            .filter( Mutation.from_account.in_([ 
                acc.account_id for acc in expenses_acc ]) ).one()
    return expenses_acc, balance


from collections import deque
 
class Simplemovingaverage():
    def __init__(self, period):
        assert period == int(period) and period > 0, "Period must be an integer >0"
        self.period = period
        self.stream = deque()
 
    def __call__(self, n):
        stream = self.stream
        stream.append(n)    # appends on the right
        streamlength = len(stream)
        if streamlength > self.period:
            stream.popleft()
            streamlength -= 1
        if streamlength == 0:
            average = 0
        else:
            average = sum( stream ) / streamlength
 
        return average


