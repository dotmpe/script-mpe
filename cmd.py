"""cmd
- get the config
- parse arguments
- some basic sys/os targets
- some aux. targets (user help)

cmd:
	pwd
	prog
	config
		-find
		-init
		-query
		-set
	options
	help
	targets
	host
	userdir
	lib
"""
import os
import sys
import re

import zope.interface

import confparse
import log
from libname import Namespace, Name
from libcmd import OptionParser, Targets, Arguments, Keywords, Options,\
	Target, optparse_increment_message, optparse_override_quiet
from res import PersistedMetaObject, Workspace
# XXX
from taxus.util import current_hostname


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

#		(('--global',),{ 'metavar':'NAME', 
#			'dest': "config_global",
#			'help': "Instead of reading the nearest value for setting, "
#				"read/set it globally. "
#			"(default: %default). " }),

		(('-K','--config-key',),{ 'metavar':'NAME', 
			'dest': "config_key",
			'default': '.',
			'help': "Get the setting value associated with given key. "
				"(default: %default). " }),

		(('-V','--config-value',),{ 'metavar':'NAME', 
			'dest': "config_value",
			'help': ""
				"(default: %default). " }),

		# XXX: old, salvage?
#		(('-K', '--config-key',),{ 'metavar':'ID', 
#			'default': klass.DEFAULT_CONFIG_KEY, 
#			'help': "Settings root node for run time configuration. "
#			" (default: %default). " }),
#
#		(('--print-config',),{ 'action':'callback', 'help': "",
#			'dest': 'command', 
#			'callback': optparse_override_handler }),
#
#		(('-U', '--update-config',),{ 'action':'store_true', 'help': "Write back "
#			"configuration after updating the conf with non-default option "
#			"values.  This will lose any formatting and comments in the "
#			"serialized configuration. ",
#			'default': False }),
		#/XXX

		(('-m', '--message-level',),{ 'metavar':'level',
			'help': "Increase chatter by lowering "
			"message threshold. Overriden by --quiet or --verbose. "
			"Levels are 0--7 (emergency--debug) with default of 5 (notice). ",
			'default': 5,
			}),

		(('-v', '--verbose',),{ 'help': "Increase chatter threshold. "
			"Overriden by --quiet or --message-level.",
			'action': 'callback',
			'callback': optparse_increment_message}),

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
def cmd_prog(prog=None):
	"""
	Command-line program static properties.
	Just assembles a few key values.
	"""
	#log.debug("{bblack}cmd{bwhite}:prog{default}")
	prog = confparse.Values(dict(
		name=os.path.splitext(os.path.basename(__file__))[0],
		version="0.1",
		argv=sys.argv[1:],
		usage="Usage % [options|targets]",
	))
	yield Keywords(prog=prog)

@Target.register(NS, 'pwd', 'cmd:prog')
def cmd_pwd():
	#log.debug("{bblack}cmd{bwhite}:pwd{default}")
	path = os.getcwd()
	yield Keywords(prog=dict(pwd=path))

@Target.register(NS, 'find-config', 'cmd:prog')
def cmd_config_find():
	#log.debug("{bblack}cmd{bwhite}:find-config{default}")
	cf = find_config_file()
	#log.debug("config_file=%s", cf)
	yield Keywords(prog=dict(config_file=cf))

@Target.register(NS, 'config', 'cmd:find-config')
def cmd_config_init(prog=None):
	"""
	Init conf object from persisted config.
	"""
	#log.debug("{bblack}cmd{bwhite}:config{default}")
	conf = confparse.load_path(prog.config_file)
	assert conf, "missing config"
	#print prog.config_file, conf
	yield Keywords(conf=conf)

@Target.register(NS, 'options', 'cmd:config')
def cmd_options(conf=None, prog=None):
	"""
	Parse arguments
	"""
	#log.debug("{bblack}cmd{bwhite}:options{default}")
	assert prog, prog
	assert conf, conf
	options = Options.get_options()
	parser, opts, kwds_, args_ = parse_argv(
			options,
			prog.argv, 
			prog.usage, 
			prog.version)
	yield Keywords(**kwds_)
	yield Keywords(
			prog=confparse.Values(dict(
				options=options,
				optparser=parser
			)),
			opts=opts,
		)
	if log.threshold != opts.message_level:
		log.note("Changing message level from %s to %s", 
				log.threshold, opts.message_level)
	log.threshold = opts.message_level
	args = Arguments()
	targs = Targets()
	args_ = list(args_)
	while args_:
		a = args_.pop()
		if re.match('[a-z][a-z0-9]+:[a-z0-9-]', a.lower()):
			targs = Targets(*(targs.items+(a,)))
		else:
			args = Arguments(args+(a,))
	yield targs
	yield args

@Target.register(NS, 'query-config', 'cmd:options')
def cmd_config_query(prog=None, opts=None, conf=None):
	#log.debug("{bblack}cmd{bwhite}:query-config{default}")
	k = opts.config_key
	k_print = k
	if '.' in k:
		if k != '.':
			k_print = ''
			i = 0
			for k1 in k.split('.'):
				k_print += "\n" + (i*'\t') + k1
				i += 1
	if k == '.':
		v = conf
		k_print = "config"
	else:
		v = conf[k]
		k_print = "config:\n\t" + "\n  ".join(k_print.split('\n'))
	print "%s: %r" % (k_print, v)

@Target.register(NS, 'set-config', 'cmd:options')
def cmd_config_set(prog=None, opts=None, conf=None):
	setattr(conf, opts.config_key, opts.config_value)

@Target.register(NS, 'help', 'cmd:options')
def cmd_help(prog=None):
	assert prog, prog
	prog.optparser.print_help()

@Target.register(NS, 'targets', 'cmd:options')
def cmd_targets(prog=None):
	"""
	XXX: deprecate? use --help.
	"""
	#log.debug("{bblack}cmd{bwhite}:targets{default}")
	prog.optparser.print_targets()
	yield Keywords(targets=prog.optparser.targets)

@Target.register(NS, 'host', 'cmd:options')
def cmd_host(prog=None):
	"""
	"""
	#log.debug("{bblack}cmd{bwhite}:host{default}")
	host = current_hostname()
	yield Keywords(prog=dict(host=host))

@Target.register(NS, 'userdir', 'cmd:options')
def cmd_userdir(prog=None, conf=None):
	userdir = os.path.expanduser(conf.cmd.lib.paths.userdir)
	yield Keywords(prog=dict(userdir=userdir))


# XXX: Illustration of the three kwd types by cmdline
import zope.interface
from zope.interface import Attribute, implements
# cmd:prog<IProgram>
class IProgram(zope.interface.Interface):
	# cmd:config
	argv = Attribute('')
	usage = Attribute('')
	name = Attribute('')
	version = Attribute('')
	# cmd:config
	config_file = Attribute('')
	# cmd:options
	options = Attribute('')
	optparser = Attribute('')
   
# cmd:opts<IOptions>
class IOptions(zope.interface.Interface):
	init = Attribute('')
	force = Attribute('')
	recurse = Attribute('')

# cmd:conf<ISettings>
class ISettings(zope.interface.Interface):
	pass
