#!/usr/bin/env python
"""cabinet - 

Restricted paths allow for interpretation.

"""
import os, re, datetime, optparse



DATE_FORMAT = "%(year)s-%(month)s-%(day)s"

SORT_DATE = 'date'
SORT_UPDATE = 'update'

ASC = 1
DESC = 2

TAB = '\t'


class Cabinet(object):
	"""
	"""

	def __init__(self, root):
		pass

	def get_tags(self):
		pass

class CabinetQuery(object):
	def add_include(self, tags): pass
	def add_exclude(self, tags): pass



usage_descr = """%prog [options] [[dir] [+tag+tag.. -tag+tag..]].." """ 

options_spec = (
	(('-t', '--tagged'), {'metavar':'TAGS', 'action':'append', 'help':
		"Filter on tag. Multiple occurences allowed, each occurence matches on the entire path. "
		"Eg. -t=foo -t=bar matches on an occurence of 'foo' and 'bar', anywhere in the path, "
		"while -t=foo+bar also matches on the given order of tags. "
		"Tags must be delimited by non alfanumeric characters. " }),
	(('-n', '--nottagged'), {'metavar':'TAGS', 'action':'append', 'help':
		"Inverse of --tagged, exclude matching paths from result. " }),

	(('-d', '--date-separator'), {'default': CabinetQuery.date_separator, 'help':
		"Used when autoformatting a path. " }),

	(('-F', '--format'), {'default': 'path', 'help':
		"Set the output format (default:%default)" }),
	(('-f', '--field-separator'), {'default': ResultPrinter.separator, 'help':
		"Set the field deliter used to separate columns (default:%default)" }),

	(('-u', '--updated'), {'help':
		"Filter output list to include only entries modified within specified date range. "
		"Requires at least the year. Month and day are separated by comma." }),
	(('-e', '--entries'), {'help':
		"Filter output list to include only entries from within specified date range. " }),

	(('-s', '--sort'), {'help':
		"Sort output list on property with order in given priority. "
		"=date:asc,update:asc" }),
)

def main(argv=[]):
	root = os.getcwd()
	cab = CabinetQuery(root)

	prsr = optparse.OptionParser(usage=usage_descr)
	for a,k in options_spec:
		prsr.add_option(*a, **k)
	opts, args = prsr.parse_args(argv)

	args.pop(0)

	for tag_spec in opts.tagged:
		cab.add_include(tag_spec)

#	for tag_spec in opts.nottag:
#		cab.add_exclude(tag_spec)

	# output results
	printer = ResultPrinter(list(cab.finalize()))
	printer.set_format(opts.format)
	printer.flush()


if __name__ == '__main__':
	import sys
	main(sys.argv)

