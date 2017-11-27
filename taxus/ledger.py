"""
.. class-uml::

	Account {
		balance:Integer
		name:String
	}

	Mutation {
		to:Account
		from:Account
		amount:Float
		currency:[EUR]
		date:Date
		description:String
		specification:String
	}
"""
from __future__ import print_function
import re
from datetime import datetime

from sqlalchemy import Column, Integer, Float, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, select, func
from sqlalchemy.orm import relationship

from taxus import core
from taxus.mixin import CardMixin
from taxus.init import SqlBase
from taxus.util import ORMMixin




ACCOUNT_CREDIT = "Account:Credit"
ACCOUNT_EXPENSES = "Expenses"
ACCOUNT_ACCOUNTING = "Expenses:Account"

class Account(SqlBase, ORMMixin):
    __tablename__ = 'accs'
    number = Column('number', Integer, primary_key=True)
    balance = Column(Integer)
    name = Column(String, unique=True, nullable=True)
    # classifiers? to match transactions
    #nl_p_number = Column(Integer, unique=True, nullable=True)
    #nl_number = Column(Integer, unique=True, nullable=True)
    #iban = Column(String, unique=True, nullable=True)
    account_id = Column('id', String, nullable=True)
    date_added = Column(DateTime, index=True, nullable=False)
    date_updated = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)

    def init_defaults(self, d):
        if not 'date_added' in d:
            d['date_added'] = d['date_updated'] = datetime.now()
        if not 'date_updated' in d:
            d['date_updated'] = datetime.now()
        return d

    def seed_defaults(self, kwds):
        for k, e in kwds.items():
            if not getattr(self, k):
                setattr(self, k, e)

    def seed(self, **kwds):
        kwds = self.init_defaults(dict(kwds))
        for k, e in kwds.items():
            setattr(self, k, e)
        return self

    def __str__(self):
        return "[Account %r #%s %s]" % ( self.name,
                self.iban or self.nl_number or self.nl_p_number,
                self.account_id)

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
            print('Unknown account number:', account_number)
            return False

    @classmethod
    def for_name_id(klass, session, account_nr, account_id=None):
        """
        Return existing or create.
        """
        acc_rs = session.query(Account).filter(
                Account.account_id == account_id).filter(
                Account.account_nr == account_nr.strip()).all()
        if acc_rs:
            acc = acc_rs[0]
        else:
            acc = Account(account_nr=account_nr.strip(), account_id=account_id)
            acc.init_defaults()
            session.add(acc)
            session.commit()
        return acc

    @classmethod
    def for_checkout(klass, session, descr):
        return klass.for_name_id(session, descr, "checkout")

    @classmethod
    def for_withdrawal(klass, session, descr):
        return klass.for_name_id(session, descr, "atm")

    @classmethod
    def for_nr(klass, session, account_number, assert_exists=False):
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
            if assert_exists:
                raise KeyError("No record for account-number %r" %
                        account_number)
            else:
                print('Unknown account number:', account_number)
            return

        if len(acc_rs) == 1:
            return acc_rs[0]
        else:
            assert not acc_rs or len(acc_rs) == 0


class Mutation(SqlBase, ORMMixin):
    """
    Temporary? table to hold mutations.
    """
    __tablename__ = 'muts'

    mut_id = Column('id', Integer, primary_key=True)
    date = Column(DateTime, index=True, nullable=False)
    from_account_nr = Column(Integer, ForeignKey('accs.number'), nullable=False)
    from_account = relationship(
            'Account', primaryjoin='Account.number==Mutation.from_account_nr')
    to_account_nr = Column(Integer, ForeignKey('accs.number'), nullable=False)
    to_account = relationship(
            'Account', primaryjoin='Account.number==Mutation.to_account_nr')
    category = Column(String, nullable=False)
    currency = Column(String(16), nullable=False)
    description = Column(Text)
    amount = Column(Float)

    def __str__(self):
        x = []
        f = ("mut_id date amount currency from_account to_account category"\
            +" description").split(' ')
        for p in f:
            x.append(getattr(self, p))
        return " ".join(map(str,x))

    @classmethod
    def forge(Klass, src, ctx, g):
        init = {}
        for c in Klass.__table__.columns:
            if hasattr(src, c.name):
                init[c.name] = getattr(src, c.name)

        init['from_account'] = ctx.assertaccount(src.from_account_nr)
        if src.debet_credit is 'C':
            init['to_account'] = ctx.assertaccount(src.to_account_nr,
                    _id=ACCOUNT_CREDIT, name=src.to_account_name)
        else:
            init['to_account'] = ctx.assertaccount(src.to_account_nr,
                    _id=ACCOUNT_EXPENSES, name=src.to_account_name)

        init['description'] = "\t".join([ getattr(src, a) for a in
                "descr descr2 descr3 descr4".split(' ')
            ])

        return Klass(**init)


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
        sa = context.get_session(settings.dbref)
    expenses_acc = Account.all((Account.name.like(ACCOUNT_EXPENSES+'%'),), sa=sa)
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

models = [

#        INode,

#
        Account,
        Mutation,
        #Simplemovingaverage
    ]
