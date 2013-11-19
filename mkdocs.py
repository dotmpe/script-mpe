#!/usr/bin/env python
import zope

import dotmpe

import libcmd
import res


class mkDoc(libcmd.SimpleCommand):
	"""
	Nov. 2013. Another iteration of mkdoc: cross-index/xform personal documents.
	"""
	zope.interface.implements(res.iface.ISimpleCommand)

	DEFAULT_ACTION = 'run_file'

	@classmethod
	def get_optspec(klass, inherit):
		"""
		Return tuples with optparse command-line argument specification.
		"""
		return (
			)

	def run_files(self, *args):
		build = dotmpe.comp.get_builder_class('mkdoc')
		builder = build()
		for a in args:
			# XXX: replace once possible
			#dotmpe.du.core.process( a, builder='mkdoc')
			#dotmpe.du.core.publish( a, reader='mkdoc', parser='rst', writer='formresults' )
			#
			document = builder.build( a, source_class=io.FileInput, reader='mkdoc' )
			
						

if __name__ == '__main__':
	mkDoc.main()

