

### User view/Debug serializers

class Formatter(object):
	def __init__(self, name):
		#print 'new', name
		self.name = name
class Formatters(object):
	names = {}
	types = {}


def cn(obj):
	return obj.__class__.__name__


class PrintedRecordMixin(object):

	_formatter = None
	@classmethod
	def get_formatter(self):
		return self._formatter
	@classmethod
	def set_formatter(self, formatter):
		assert formatter.name and formatter.format
		self._formatter = formatter
		return self._formatter
	formatter = property(get_formatter, set_formatter)

	def get_format_name(self):
		if self._formatter:
			return self._formatter.name
	def set_format_name(self, name):
		assert name in Formatters.names
		self._formatter = Formatters.names[name](name)
		return self._formatter
	record_format = property(get_format_name, set_format_name)

#	def __call__(cls, *args, **kwds):
#		print 'rec mixin call', args
#		super(PrintedRecordMixin, cls).__call__(cls, *args, **kwds)
#		return cls
#
#	def __init__(self, *args, **kwds):
#		print 'rec mixin init', args
#		if 'formatter' in kwds:
#			self.formatter = kwds['formatter']
#			del kwds['formatter']
#		elif 'record_format' in kwds:
#			self.record_format = kwds['record_format']
#			del kwds['record_format']
#		else:
#			self.record_format = 'default'
#		print self.formatter, self.record_format
#		super(PrintedRecordMixin, self).__init__(self, *args, **kwds)

	def __repr__(self):
		if not self.formatter:
			name = cn(self)
			if self.__class__ in Formatters.types:
				self.formatter = Formatters.types[self.__class__]('repr_'+name)
			else:
				return "<Static %s at %s>" % (name, id(self))
		return self.formatter.format(self)


### Register some formatters

class RecordRepr(Formatter):
	def format(self, record):
		name = cn(record)
		return "<%s Record %i at %s>" % (name, record.id, id(record))

Formatters.names['default'] = RecordRepr


class Format2(Formatter):
	def format(self, record):
		name = cn(record)
		return "<%s #%i: \"%s\">" % (name, record.id, record.name)

Formatters.names['default'] = Format2


class RecordFields(Formatter):
	def format(self, record):
		fields = ["%s: %s" % (k.key, getattr(record, k.key)) for k in record.__mapper__.iterate_properties]
		name = cn(record)
		return "%s(%s)" % (name, ', '.join(fields))

Formatters.names['identity'] = RecordFields



