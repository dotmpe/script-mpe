#!/usr/bin/env python
"""mycalendar - 
"""

import zope

import libcmd
import res


class Calendar(object):
	@classmethod
	def walk(Klass, path):
		"""
			path -> year
				path -> month
					path -> day
		calendartable	
			year
				path,
				months
			month
				path,
				days
			day
				path
		"""

		calendartable = {
		}

		thisYear, thisMonth, thisDay = None, None, None
		# Go top down
		for root, nodes, leafs in os.walk(path):
			if root in calendartable:
				thisYear = calendartable[root]
			for name in list(nodes):
				p = os.path.join(root, name)
				if name.isdigit():
					tryYear = int(name)
					if tryYear > 1200 and tryYear < 2099:
						thisYear = tryYear
						calendartable[thisYear] = p
					pass

class calendarCLI(libcmd.SimpleCommand):

	zope.interface.implements(res.iface.ISimpleCommand)

	@classmethod
	def get_optspec(klass, inherit):
		"""
		"""
		return ()

	DEFAULT_ACTION = 'run_'

	def run_(self, *args):
		for p in args:
			Calendar.walk(p)


if __name__ == '__main__':
	calendarCLI.main()

