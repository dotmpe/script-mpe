from __future__ import print_function
import csv
import hashlib
from datetime import datetime

from .idxattr import IndexAttributeWrapper
from .attrmap import AttributeMapWrapper


DTFMT = '%Y%m%d'

def csvreader(csvfile, fields, mutations, unique_fields=False, unique_records=True, opts=False):
	"""Generator"""
	global ctx

	reader = csv.reader(open(csvfile), delimiter=',')
	line = 0 # csv.reader iteration count
	# prepare for unique_fields
	seen = {}
	if unique_fields:
		if not isinstance(unique_fields, list):
			assert isinstance(unique_fields, list)
			unique_fields = fields
		seen = dict(zip( unique_fields, [ [] for n in unique_fields ] ))
	skipping = 0 # track skipping with unique_records
	for row in reader:
		line += 1

		# old and new style records (IBAN)
		if len(row) == 16:
			accnr, curr, date, DC, amount, destacc, destname, \
							date2, cat, _1, \
							descr, descr2, descr3, descr4, _2, _3 = row

		elif len(row) == 19:
			accnr, curr, date, DC, amount, destacc, destname, \
							date2, cat, _1, \
							descr, descr2, descr3, descr4, _2, _3, \
							nr1, accnr2, nr2 = row
			accnr = accnr[8:]

		elif row == ['\x1a']:
			continue
		else:
			assert False, len(row)

		date = datetime.strptime(date, DTFMT)
		date2 = datetime.strptime(date2, DTFMT)

		# track/skip for unique_records
		if unique_records:
			key = hashlib.sha1(datetime.strftime(date, DTFMT))
			key.update(accnr)
			key.update(destacc)
			key.update(amount)
			key.update(cat)
			key.update(descr)
			key.update(descr2)
			key = key.hexdigest()
			if key in mutations:
				skipping += 1
				continue
			elif skipping:
				print('Skipped', skipping, 'lines, %s' % ( csvfile))
				skipping = 0
			mutations[key] = True
		if opts:
			# skip for start/end date
			if opts.start_date:
				start_date = datetime.strptime(opts.start_date, '%Y-%m-%d')
				if start_date >= datetime.strptime(date, '%Y%m%d'):
					#print 'skipped', csvfile, line, date
					continue
			if opts.end_date:
				end_date = datetime.strptime(opts.end_date, '%Y-%m-%d')
				if end_date < datetime.strptime(date, '%Y%m%d'):
					#print 'skipped', csvfile, line, date
					continue
		# parse some..
		amount = float(amount)
		if DC.upper() == 'D':
			amount = 0-amount
		# track changed fields
		new = False
		if seen:
			for i, n in enumerate(unique_fields):
				v = locals()[n]
				if v:
					newnew = new or v not in seen[n]
					if new and not newnew:
						break
					new = newnew
		# yield if new (changed or unique) and everything if not tracking
		if new or not seen:
			# one last check to see wether we understood the input data
			if destacc == '0000000000':
				if cat == 'ba':
					pass# betaalautomaat
				elif cat == 'ga':
					pass# geldautomaat
				elif cat == 'ck':
					pass# chipknip, opladen?
				elif cat == 'db':
					pass# kosten bankzaken
				elif descr == 'Rente over periode':
					pass
				else:
					assert False, (destacc, destname, cat, row)
			else:
				assert cat in ('ma', 'ba', 'ga', 'cb', 'id', 'db', 'bg', 'ac', 'ei'), cat
			vs = [ locals()[n] for n in fields ]
			if unique_fields and seen:
				vc = [ locals()[n] for n in unique_fields ]
				for i, v in enumerate(vc):
					n = unique_fields[i]
					seen[n].append(v)
			yield tuple(vs)


# Utils. for rabo CSV mutations parser

csvreader.fields = ("accnr curr date DC amount destacc destname date2 "+
	"cat descr descr2 descr3 descr4").split(' ')

csvreader.fieldmap = lambda adaptee: \
    IndexAttributeWrapper(adaptee, csvreader.fields)

# translate csv parser vars to matching names used by taxus.ledger models
csvreader.attributes = ("from_account_nr currency date debet_credit "+
    "amount to_account_nr to_account_name date2 "+
	"category descr descr2 descr3 descr4").split(' ')
csvreader.attrs = dict(zip(csvreader.attributes, csvreader.fields))

csvreader.attrmap = lambda adaptee: \
    AttributeMapWrapper(csvreader.fieldmap(adaptee), csvreader.attrs)
