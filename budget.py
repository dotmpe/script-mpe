#!/usr/bin/env python
__version__ = '0.0.0'
__db__ = '~/.budget.sqlite'
__usage__ = """
budget - simple balance tracking accounting software.

Usage:
  budget [options] balance [commit|rollback]
  budget [options] mutation ( list [ <id> | <filter> ] | import [-f <format>] <file>... )
  budget [options] account ( list | [ ( add | show | update | rm ) <name> ] )
  budget [options] db (init|reset|stats)
  budget [options] month
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

    --end-balance INT
    --start-balance INT

    --first-month YEAR-MONTH
    --last-month YEAR-MONTH
    -x <xyz>

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
from docopt import docopt

import util
import confparse
from myLedger import SqlBase, metadata, get_session, \
        AccountBalance, \
        Account, \
        Year, Month, \
        Mutation, \
        models,\
        valid_iban, valid_nl_number, valid_nl_p_number
from rabo2myLedger import \
        print_gnu_cash_import_csv, \
        print_sum_from_files, \
        csv_reader




ACCOUNT_ACCOUNTING = "Bankzaken"


def cmd_db_init(settings):
    """
    Initialize if the database file doest not exists,
    and update schema.
    """
    get_session(settings.dbref)
    # XXX: update schema..
    metadata.create_all()

def cmd_db_stats(settings):
    """
    Print table record stats.
    """
    sa = get_session(settings.dbref)
    print "Accounts:", sa.query(Account).count()
    print "AccountBalances:", sa.query(AccountBalance).count()
    print "Mutations:", sa.query(Mutation).count()
    print "Years:", sa.query(Year).count()
    print "Months:", sa.query(Month).count()

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
    metadata.create_all()

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
    print "Added account", name

def cmd_account_update(settings):
    print 'account-update'

def cmd_account_rm(settings, name):
    sa = get_session(settings.dbref)
    acc = sa.query(Account).filter(Account.name == name).one()
    sa.delete(acc)
    sa.commit()
    print "Dropped account", name

def cmd_change_list(settings):

    """
    """

    sa = get_session(settings.dbref)
    for month in sa.query(Month).all():
        print m.year, m.mon

def cmd_month(settings):

    """
    Print balance change per month. 
    --month-start --month-end
    Default to 
    """

    sa = get_session(settings.dbref)

    start = settings.first_month \
            if 'first_month' in settings and settings.first_month else datetime.now()
    end = settings.last_month \
            if 'last_month' in settings and settings.last_month else datetime.now()
    print '# Range: ', start.year, start.month, '--', end.year, end.month
    
    last5 = []
    print '# year, month, amount, 5avg'
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
                last5.append(amount)
                if len(last5) > 5:
                    last5.pop(0)
                avg = sum(last5) / len(last5)
                print year, month, amount, avg


def cmd_balance_verify(opts):

    """
    TODO: Print or verify balance since last check.
    """

def cmd_mutation_import(opts, settings):

    """
    Import mutations from CSV, create accounts as needed.
    Indx with Year, Month.
    """

    sa = get_session(settings.dbref)

    #period = Period.get_current_or_new(settings)
    #if period.isNew:
    #    log.std("Started new period")
    #else:
    #    log.std("Using existing open period %s", period)

    assert settings.input_format == 'csv', settings.input_format
    cache = confparse.Values(dict(
        accounts={}, years={}, months={}
    ))
    for csvfile in opts['<file>']:
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
                    from_account = Account(name=destname)
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
                    to_account = Account.for_checkout(sa, descr)
                elif cat == 'ga':
                    # atm withdrawal
                    to_account = Account.for_withdrawal(sa, descr)
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
                    to_account = Account(name=destname)
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

        log.std("Auto-adjusting period to import date range")


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

def cmd_balance_commit(opts):

    """
    TODO: Commit current balance or insert a book check.
    """

    period = Period.get_current_or_new()
    # TODO close period

def cmd_balance_rollback(opts):

    """
    TODO: Reverse last commit.
    """

    # check for open period
    period = Period.get_current()


### Transform cmd_ function names to nested dict

commands = util.get_cmd_handlers(globals(), 'cmd_')


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags

    if not re.match(r'^[a-z][a-z]*://', settings.dbref):
        settings.dbref = 'sqlite:///' + os.path.expanduser(settings.dbref)

    return util.run_commands(commands, settings, opts)

def get_version():
    return 'budget.mpe/%s' % __version__

argument_handlers = {
        '<xyz>': lambda v: int(v)+5,
        'DATE': lambda v: datetime.strptime(v, '%Y-%m-%d'),
        'YEAR-MONTH': lambda v: datetime.strptime(v, '%Y-%m')
}

if __name__ == '__main__':
    import sys
    opts = util.get_opts(__usage__, meta=argument_handlers, version=get_version())
    sys.exit(main(opts))

