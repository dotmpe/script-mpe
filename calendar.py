#!/usr/bin/env python
"""calendar - 
"""

import zope

import libcmd
import res

class calendarCLI(libcmd.SimpleCommand):
	zope.interface.implements(res.iface.ISimpleCommand)


if __name__ == '__main__':
	calendarCLI.main()
