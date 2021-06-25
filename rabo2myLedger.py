#!/usr/bin/env python
"""
:Created: 2014-08-24
"""
from __future__ import print_function


def print_gnu_cash_import_csv(csvfile, description_delimiter='\n', opts=None):
	reader = csv.reader(open(csvfile), delimiter=',')
	for row in reader:
		if len(row) == 16:
			accnr, curr, date, DC, amount, \
				destacc, destname, date2, cat, _,\
				descr, descr2, descr3, descr4, _, _ = row

		elif len(row) == 19:
			accnr, curr, date, DC, amount, \
					destacc, destname, date2, cat, _,\
					descr, descr2, descr3, descr4, _, \
					_, nr1, accnr2, n2 = row
			accnr = accnr[8:]

		elif row == ['\x1a']:
			break
		else:
			assert False, len(row)

		dt = date[:4] +'-'+ date[4:6] +'-'+ date[6:8]
		d = description_delimiter.join([
			d for d in descr, descr2, descr3, descr4 if d.strip()])
		debet = DC.upper() == 'D'
		out = dt, debet and amount or "", not debet and amount or "", destacc, destname, d
		print(",".join( map(lambda x: '"%s"' % x, out) ))

def set_account_category(opts, account, category=None):
	# account must exist
	if isinstance(account, str):
		account = opts._sa.query(Account).filter(Account.account_number == account).one()
		print(account)
	if not category:
		if account.account_type == None:
			account.account_type = ''
		ok = False
		while not ok:
			category = Prompt.input("Please enter/update the classification: ",
					account.account_type)
			acctypes = opts._sa.query(Account).filter(Account.account_type == category).first()
			if acctypes:
				ok = True
			elif not acctypes:
				ok = Prompt.ask("Is new category %r correct?" % category, 'yN')
				if not ok:
					if Prompt.query("Cancel?", 'Yn'):
						break
	if category:
		if account.account_type != category:
			account.account_type = category
			opts._sa.add(account)
			opts._sa.commit()
			print("Updated", account)

def organize(opts, account=None, category=None):
	opts._sa = sa = init.get_session(opts.dbref)
	if account:
		set_account_category(opts, account, category)
	else:
		accounts = sa.query(Account).all()
		for account in accounts:
			print(account)
			set_account_category(opts, account)



def main():
	import sys
	from getopt import getopt
	opts, args = getopt(sys.argv[1:], 'hl:g', [
		'list-accounts',
		'delete-account',
		'organize',
		'reset-db',
#		'ledger-dbname=',
#		'ledger-db=',
		'import',
		'print-mutations-csv',
		'gnu-cash-csv',
		'start-date=',
		'end-date=',
		'start-balance=',
		'end-balance=',
	])
	settings = confparse.Values(dict(
		start_date=None, end_date=None,
		start_balance=None, end_balance=None
	))
	settings.dbrefname = '~/.myLedger.sqlite'
	settings.dbref = 'sqlite:///%s' % os.path.expanduser(settings.dbrefname)
	log.stderr("Using dbref %r" % settings.dbrefname)
	settings._sa = sa = init.get_session(settings.dbref)
	# options should be in sequence, one command at the end
	cmd, cargs = None, ()
	for o in opts:
		if '--gnu-cash-csv' in o:
			for a in args:
				print_gnu_cash_import_csv(a, '\t', settings)
			return
		elif '--start-balance' in o:
			print("Warning: start-balance option ignored ", file=sys.stderr)
		elif '--start-date' in o:
			settings.start_date = o[1]
		elif '--end-date' in o:
			settings.end_date = o[1]
		elif '--end-balance' in o:
			settings.end_balance = float(o[1])
		elif '--print-mutations-csv' in o:
			cmd, cargs = 'print_sum_from_files', [settings, ] + args
		# Account commands
		elif '--import-accounts' in o:
			sa = init.get_session(opts.dbref)
			for a in args:
				import_accounts_from_file(sa, a, settings)
			return
		elif '--organize' in o:
			cmd, cargs = 'organize', [settings, ] + args
		elif '--delete-account' in o:
			cmd, cargs = 'drop_account', [settings, ] + args

	if cmd in globals():
		return globals()[cmd](*cargs)
