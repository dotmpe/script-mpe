"""
"""

from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
	Target 


NS = Namespace.register(
		prefix='htdocs',
		uriref='http://project.dotmpe.com/script/#/htdocs'
	)

Options.register(NS, 
#				(('--init-host',), {
#					'action': 'callback', 
#					'callback_args': ('init_host',),
#					'dest': 'command', 
#					'callback': libcmd.optparse_override_handler,
#					'help': "TODO" }),
		)


@Target.register(NS, 'update', 'txs:session')
def htdocs_update(sa=None, ur=None, opts=None, settings=None):
	comp.get_builder_class('dotmpe.du.builder.htdocs')
	frontend.cli_process(source, builder_name='htdocs')


