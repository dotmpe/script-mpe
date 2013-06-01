"""cmdline - basis implementation of libcmd for taxus, rsr and other script
utils.

See libcmd or other programs for usage overviews.
"""
import os
import sys
import re

import zope.interface

import confparse
import log
from libname import Namespace, Name
from libcmd import OptionParser, Targets, Arguments, Keywords, Options,\
	Target, optparse_decrement_message, optparse_override_quiet


# Register this module with libcmd

DEFAULT_RC = 'cllct.rc'
	   
NS = Namespace.register(
		prefix='cmd',
		uriref='http://project.dotmpe.com/script/#/cmdline'
	)

Options.register(NS, 

		(('-c', '--config',),{ 'metavar':'NAME', 
			'dest': "config_file",
			'default': DEFAULT_RC, 
			'help': "Run time configuration. This is loaded after parsing command "
			"line options, non-default option values wil override persisted "
			"values (see --update-config) (default: %default). " }),

		# XXX: old, salvage?
#		(('-K', '--config-key',),{ 'metavar':'ID', 
#			'default': klass.DEFAULT_CONFIG_KEY, 
#			'help': "Settings root node for run time configuration. "
#			" (default: %default). " }),
#
#		(('--init-config',),{ 'action': 'callback', 'help': "(Re)initialize "
#			"runtime-configuration with default values. ",
#			'dest': 'command', 
#			'callback': optparse_override_handler }),
#
#		(('--print-config',),{ 'action':'callback', 'help': "",
#			'dest': 'command', 
#			'callback': optparse_override_handler }),
#
#		(('-U', '--update-config',),{ 'action':'store_true', 'help': "Write back "
#			"configuration after updating the settings with non-default option "
#			"values.  This will lose any formatting and comments in the "
#			"serialized configuration. ",
#			'default': False }),
		#/XXX

		(('-m', '--message-level',),{ 'metavar':'level',
			'type': 'int',
			'help': "Increase chatter by lowering "
			"message threshold. Overriden by --quiet or --verbose. "
			"Levels are 0--7 (debug--emergency) with default of 2 (notice). "
			"Others 1:info, 3:warning, 4:error, 5:alert, and 6:critical.",
			'default': 2,
		}),

		(('-v', '--verbose',),{ 'help': "Increase chatter by lowering message "
			"threshold. Overriden by --quiet or --message-level.",
			'action': 'callback',
			'callback': optparse_decrement_message}),

		(('-Q', '--quiet',),{ 'help': "Turn off informal message (level<4) "
			"and prompts (--interactive). ", 
			'dest': 'quiet', 
			'default': False,
			'action': 'callback',
			'callback': optparse_override_quiet }),

		(('--interactive',),{ 'help': "Force user prompt in certain "
			"situations. This is the default. ", 
			'default': True,
			'action': 'store_true' }),

		(('--non-interactive',),{ 
			'help': "Never prompt, auto-solve situation by defaults or "
			"preferences. Otherwise raise error for unclear or risky "
			"situations. But remember user preferences may override! "
			"This option should ensure execution completes unattended, "
			"and as soon soon as possible, but early failure cannot always "
			"be guaranteed. ", 
			'dest': 'interactive', 
			'default': True,
			'action': 'store_false' })

	)


# Util functions

def parse_argv(options, argv, usage, version):
	"""
	Given the option spec and argument vector,
	parse it into a dictionary and a list of arguments.
	Uses Python standard library (OptionParser).
	Returns a tuple of the parser and option-values instances,
	and a list left-over arguments.
	"""
	# TODO: rewrite to cllct.osutil once that is packaged
	#parser, opts, paths = parse_argv_split(
	#		self.OPTIONS, argv, self.USAGE, self.VERSION)

	parser = OptionParser(usage, version=version)

	optnames = []
	nullable = []
	for opt in options:
		parser.add_option(*opt[0], **opt[1])

	optsv, args = parser.parse_args(argv)

	optsd = {}
	for name in dir(optsv):
		v = getattr(optsv, name)
		if not name.startswith('_') and not callable(v):
			optsd[name] = v

	return parser, optsv, optsd, args

def find_config_file():
	rcfile = list(confparse.expand_config_path(DEFAULT_RC))
	if rcfile:
		config_file = rcfile.pop()
	else:
		config_file = DEFAULT_RC
	"Configuration filename."

	if not os.path.exists(config_file):
		assert False, "Missing %s, perhaps use init_config_file"%config_file
	
	return config_file


# 

@Target.register(NS, 'prog')
def cmd_prog():
	"""
	Command-line program static properties.
	"""
	log.debug("{bblack}cmd{bwhite}:prog{default}")
	prog = confparse.Values(dict(
		argv=sys.argv[1:],
		usage="Usage % [options|targets]",
		name=os.path.splitext(os.path.basename(__file__))[0],
		version="0.1",
		pwd=os.getcwd(),
		home=os.getenv('HOME')
	))
	assert prog.home, "What, no homefolder? Are you a user even"
	yield Keywords(prog=prog)

@Target.register(NS, 'config', 'cmd:prog')
def cmd_config(prog=None):
	"""
	Init settings object from persisted config.
	"""
	log.debug("{bblack}cmd{bwhite}:config{default}")
	assert prog, prog
	config_file = find_config_file()

	prog.update(dict(
		config_file=config_file,
	))
	yield Keywords(
			settings=confparse.load_path(config_file))

@Target.register(NS, 'options', 'cmd:config')
def cmd_options(settings=None, prog=None):
	"""
	Parse arguments
	"""
	log.debug("{bblack}cmd{bwhite}:options{default}")
	parser, opts, kwds_, args_ = parse_argv(
			Options.get_options(), 
			prog['argv'], 
			prog['usage'], 
			prog['version'])
	prog.update(dict(
		optparser=parser,
	))
	# Yield parsed invocation back to TargetResolver
	yield Keywords(**kwds_)
	yield Keywords(
		opts=opts,
	)
	print "Verbosity:", opts.message_level
	args = Arguments()
	targs = Targets()
	args_ = list(args_)
	while args_:
		a = args_.pop()
		if re.match('[a-z][a-z0-9]+:[a-z0-9-]', a.lower()):
			targs = Targets(targs+(a,))
		else:
			args = Arguments(args+(a,))
	yield targs
	yield args
	# Do some post initialization (XXX: does this part of a generator always # exec?)
	log.category = opts.message_level

@Target.register(NS, 'help', 'cmd:options')
def cmd_help(settings=None, prog=None):
	log.debug("{bblack}cmd{bwhite}:help{default}")
	prog['optparser'].print_help()

@Target.register(NS, 'targets', 'cmd:options')
def cmd_targets(settings=None, prog=None):
	"""
	xxx: deprecate? use --help.
	"""
	log.debug("{bblack}cmd{bwhite}:targets{default}")
	optparser = prog['optparser']
	optparser.print_targets()
	yield Keywords(targets=optparser.targets)


