#!/usr/bin/env python
__version__ = '0.0.3-dev' # script-mpe
__db__ = '~/.budget.sqlite'
__usage__ = """
budget - simple balance tracking accounting software.

Usage:
  budget [options] balance [verify|commit]
  budget [options] mutation ( list [ <id> | <filter> ] | import [-f <format>] <file>... )
  budget [options] account ( list | [ ( add | show | update | rm ) <name> ] )
  budget [options] db (init|reset|stats)
  budget [options] month
  budget [options] corrections
  budget [account add] ( -p PROPERTY=VALUE )...
  budget help
  budget -h|--help
  budget --version

Options:
    -v            Increase verbosity.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s].
    -f --input-format=FORMAT
                  Input format [default: csv].
    -y --yes

    --reset       Truncate mutation table upon import. Does not clear anything else.

    --end-balance INT
    --start-balance INT

    --first-month YEAR-MONTH
    --last-month YEAR-MONTH

    -A --account=NAME-OR-ID
    -M --mutation=NAME-OR-ID
    -P --period=NAME-OR-ID

    -p --props=NAME=VALUE
    -n --name=NAME
    -c --category=CAT
    -a --amount=AMOUNT [default: 0.0]
    -i --from-account=NAME-OR-ID
    -o --to-account=NAME-OR-ID
    -t --description=DESCRIPTION
    -d --day=DAY-OF-MONTH
    -m --month=MONTH-OF-YEAR
    -y --year=YEAR

    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__ )
import os
import re
from datetime import datetime
from pprint import pformat

from sqlalchemy import func

import lib
import log
import util
import confparse
import taxus
from myLedger import SqlBase, metadata, get_session, \
        Account, \
        Mutation, \
        models,\
        valid_iban, valid_nl_number, valid_nl_p_number, \
        fetch_expense_balance, \
        Simplemovingaverage,\
        ACCOUNT_CREDIT, ACCOUNT_EXPENSES, ACCOUNT_ACCOUNTING
from rabo2myLedger import \
        print_gnu_cash_import_csv, \
        print_sum_from_files, \
        csv_reader



def cmd_db_init(settings):

    """
    Initialize if the database file doest not exists,
    and update schema.
    """

    sa = get_session(settings.dbref)
    # XXX: update schema..
    metadata.create_all()
    accounting_acc = Account(name=ACCOUNT_ACCOUNTING)
    accounting_acc.init_defaults()
    expenses_acc = Account(name=ACCOUNT_EXPENSES)
    expenses_acc.init_defaults()
    credit_acc = Account(name=ACCOUNT_CREDIT)
    credit_acc.init_defaults()
    sa.add(accounting_acc)
    sa.add(expenses_acc)
    sa.add(credit_acc)
    sa.commit()


def cmd_db_stats(settings):

    """
    Print table record stats.
    """

    sa = get_session(settings.dbref)
    print "Accounts:", sa.query(Account).count()
    print "Mutations:", sa.query(Mutation).count()


def cmd_db_reset(settings):

    """
    Drop all tables and recreate schema.
    """

    get_session(settings.dbref)
    if not settings.yes:
        x = raw_input("This will destroy all data? [yN] ")
        if not x or x not in 'Yy':
            return 1
    metadata.drop_all()
    cmd_db_init(settings)


def cmd_account_show(settings):
    sa = get_session(settings.dbref)
    accid = int(opts['<name>'])
    for acc in sa.query(Account).filter(Account.account_id==accid).all():
        print "\t".join(map(str,(acc.account_id, acc.name, acc.iban)))

def cmd_account_list(settings):
    sa = get_session(settings.dbref)
    for acc in sa.query(Account).all():
        print "\t".join(map(str,(acc.account_id, acc.name)))

def cmd_account_add(props, settings, name):
    sa = get_session(settings.dbref)
    acc = Account(name=name)
    sa.add(acc)
    sa.commit()
    log.std("Added account %s", name)

def cmd_account_update(settings):
    print 'TODO account-update'

def cmd_account_rm(settings, name):
    sa = get_session(settings.dbref)
    acc = sa.query(Account).filter(Account.name == name).one()
    sa.delete(acc)
    sa.commit()
    log.std("Dropped account %s", name)


def cmd_month(settings):

    """
    Print balance change per month.
    --first-month --last-month
    """

    sa = get_session(settings.dbref)

    start = settings.first_month \
            if 'first_month' in settings and settings.first_month else datetime.now()
    end = settings.last_month \
            if 'last_month' in settings and settings.last_month else datetime.now()
    print '# Range: ', start.year, start.month, '--', end.year, end.month

    balance = 0
    last3 = Simplemovingaverage(3)
    last6 = Simplemovingaverage(6)
    last12 = Simplemovingaverage(12)
    last24 = Simplemovingaverage(24)

    print '# year, change, amount, balance, avg6, avg12'
    for year in range(start.year, end.year+1):
        if year == start.year and year == end.year:
            months = range(start.month, end.month+1)
        elif year == start.year:
            months = range(start.month, 13)
        elif year == end.year:
            months = range(1, end.month+1)
        else:
            months = range(1, 13)
        for month in months:
            amount, = sa.query(func.sum(Mutation.amount))\
                    .filter( Mutation.year == year, Mutation.month == month ).one()
            if amount:
                balance += amount
                avg3 = last3(amount)
                avg6 = last6(amount)
                avg12 = last12(amount)
                avg24 = last24(amount)
                print ("%(year)04i-%(month)02i "\
                    "%(balance)9.2f EUR "\
                    "%(amount)9.2f "\
                    "%(avg3)9.2f "\
                    "%(avg6)9.2f %(avg12)9.2f %(avg24)9.2f" ) % locals()
                #print year, month, amount, avg6, avg12, balance


def cmd_mutation_import(opts, settings):

    """
    Import mutations from CSV, create accounts as needed.
    Indx with Year, Month.
    """

    sa = get_session(settings.dbref)
    if settings.reset or lib.Prompt.ask("Purge mutations?"):
        sa.query(Mutation).delete()
        log.std("Purged all previous mutations")

    assert settings.input_format == 'csv', settings.input_format
    cache = confparse.Values(dict(
        accounts={}, years={}, months={}
    ))
    for csvfile in opts.args.file:
        reader = csv_reader(csvfile, [
            'line', 'date', 'accnr', 'amount', 'destacc', 'cat',
            'destname', 'descr', 'descr2' ])
        for line, date, accnr, amount, destacc, cat, destname, descr, descr2 in reader:
            from_account, to_account = None, None
            assert accnr, (line, date, amount, cat)
            # from_account
            if accnr not in cache.accounts:
                from_account = Account.for_nr(sa, accnr)
                if not from_account:
                    from_account = Account(name=ACCOUNT_CREDIT+':'+accnr)
                    from_account.init_defaults()
                from_account.set_nr(accnr)
                sa.add(from_account)
                sa.commit()
                cache.accounts[accnr] = from_account
            else:
                from_account = cache.accounts[accnr]
            assert from_account.account_id, (str(from_account), line, accnr, date, amount, cat)

            # credit account
            if not destacc:
                if cat == 'ba':
                    # payment card checkout
                    to_account = Account.for_checkout(sa,
                            ACCOUNT_EXPENSES+':ba:'+descr)
                elif cat == 'ga':
                    # atm withdrawal
                    to_account = Account.for_withdrawal(sa,
                            ACCOUNT_EXPENSES+':ga:'+descr)
                elif cat == 'db':
                    # debet interest
                    to_account = Account.for_name_type(sa, ACCOUNT_ACCOUNTING)
                else:
                    print line, date, accnr, amount, cat, descr, descr2
                    assert not destname, (cat, destname, cat)
                    continue
            # billing account
            elif destacc not in cache.accounts:
                to_account = Account.for_nr(sa, destacc)
                if not to_account:
                    to_account = Account(name=ACCOUNT_EXPENSES+':'+destname)
                    to_account.init_defaults()
                to_account.set_nr(destacc)
                sa.add(to_account)
                sa.commit()
                cache.accounts[destacc] = to_account
            else:
                to_account = cache.accounts[destacc]
            # get Year/Month
            y, m, d = map(int, ( date[:4], date[4:6], date[6:]))
            if y not in cache.years:
                pass
            mut = Mutation(
                    from_account=from_account.account_id,
                    to_account=to_account.account_id,
                    year=y, month=m, day=d,
                    amount=amount, description=descr+'\t'+descr2,
                    category=cat)
            sa.add(mut)
            sa.commit()

    log.std("Import ready")

    cmd_balance_commit(settings)


def cmd_mutation_list(settings, opts):

    """
    List mutation ID, year, from-/to-account and amount.
    """

    sa = get_session(settings.dbref)
    if opts['<id>']:
        accid = int(opts['<id>'])
        for m in sa.query(Mutation).filter(
                Mutation.from_account == accid or
                Mutation.to_account == accid
                ).all():
            print m.mut_id, m.year, m.from_account, m.to_account, m.amount
    else:
        for m in sa.query(Mutation).all():
            print m.mut_id, m.year, m.from_account, m.to_account, m.amount

    return 0


def cmd_balance_verify(settings, sa=None):

    """
    Print balance for expence accounts.
    """

    if not sa:
        sa = get_session(settings.dbref)

    expenses_acc = Account.all((Account.name.like(ACCOUNT_CREDIT+'%'),), sa=sa)
    balances = [ sa.query(func.sum(Mutation.amount))\
            .filter( Mutation.from_account == acc.account_id )
            .one() for acc in expenses_acc ]

    for i, (sub, (sub_balance,)) in enumerate(zip(expenses_acc, balances)):
        print i, sub.name, sub.iban or sub.nl_number or sub.nl_p_number, sub_balance

    return 0

def cmd_corrections(settings):
    sa = get_session(settings.dbref)
    for rs in sa.query( Mutation ).filter( Mutation.category == 'sb' ).all():
        print rs

def cmd_balance_commit(settings):

    """
    TODO: Commit current balance, insert corrections where needed.
    """

    sa = get_session(settings.dbref)
    cmd_balance_verify(settings, sa=sa)
    accounts, balance = fetch_expense_balance(settings, sa=sa)

    if lib.Prompt.ask("End balance %s, correct?" % balance):
        return 0

    ia = int(lib.Prompt.raw_input("Which account [0-%i]" % (len(accounts)-1)))
    account = accounts[ia]
    print ia, account

    v = float(lib.Prompt.raw_input("Enter the actual balance"))
    correction = v - balance
    print 'Correction: ', balance, correction, balance+correction

    d = None
    while not d:
        sd = lib.Prompt.raw_input("Enter a year, month, or full day to enter",
                datetime.now().strftime('%Y-%m-%d'))
        for fmt in '%Y-%m-%d', '%Y-%m', '%Y':
            try:
                d = datetime.strptime(sd, fmt)
            except:
                pass

    c = Mutation(
            amount=correction,
# XXX circular ledger, isnt really valid..
            from_account=account.account_id,
            to_account=account.account_id,
            category='sb',
            day=d.day, month=d.month, year=d.year,
            description="Correction/starting balance"
    )
    print c
    if lib.Prompt.ask("Commit?"):
        sa.add(c)
        sa.commit()
        return 0

    return 1


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = ['balance', 'verify']
    return util.run_commands(commands, settings, opts)

def get_version():
    return 'budget.mpe/%s' % __version__

argument_handlers = {
        'DATE': lambda v: datetime.strptime(v, '%Y-%m-%d'),
        'YEAR-MONTH': lambda v: datetime.strptime(v, '%Y-%m')
}

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__usage__, meta=argument_handlers, version=get_version())
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))



