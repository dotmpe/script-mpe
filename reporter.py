"""
zope.interfaces based output component model.

XXX: see log, taxus_out for older model.
"""
import collections


class Reporter(object):

	"""
	Facade to hold an aggregate of report objects,
	ie. lists of messages, tables, trees and other complex objects.
	"""

	def __init__(self):
		self.data = {}

	def update(self, data):
		"""
		Add data, object that implements IResult.
		"""
		self.__class__.deepupdate(self.data, data)

	@classmethod
	def deepupdate(Class, sub, data):
		for k, v in data.iteritems():
			if isinstance(v, collections.Mapping):
				r = Class.deepupdate(sub.get(k, {}), v)
				sub[k] = r
			elif isinstance(v, list):
				if k in sub:
					assert isinstance(sub[k], list)
				else:
					sub[k] = []
				sub[k].extend(v)
			else:
				sub[k] = data[k]
		return sub

	def flush(self):
		for k in self.data:
			print "%s" % k
			for k2 in self.data[k]:
				print "   %s" % k2
				for i in self.data[k][k2]:
					print "      - %s " % i

# XXX: work in progress
#class TableReporter(object):
#
#	def __init__(self):
#		self.rowcols = {}
#		self.colheaders = []

