"""
Filesystem metadata & management routines.

See Resourcer.rst
"""
import os
import shelve
from pprint import pformat

import lib
import log
import confparse
import res
from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
	Target 



NS = Namespace.register(
		prefix='rsr',
		uriref='http://project.dotmpe.com/script/#/cmdline.Resourcer'
	)

Options.register(NS, 

		(('-F', '--output-file'), { 'metavar':'NAME', 
			'default': None, 
			'dest': 'outputfile',
			}),

		(('-R', '--recurse', '--recursive'),{ 
			'dest': "recurse",
			'default': False,
			'action': 'store_true',
			'help': "For directory listings, do not descend into "
			"subdirectories by default. "
		}),

		(('-f', '--force' ),{ 
			'default': False,
			'action': 'store_true'
		}),
		(('-r', '--reset' ),{ 
			'default': False,
			'action': 'store_true'
		}),

		(('-L', '--max-depth', '--maxdepth'),{ 
			'dest': "max_depth",
			'default': -1,
			'help': "Recurse in as many sublevels as given. This may be "
			" set in addition to 'recurse'. 0 is not recursing and -1 "
			"means no maximum level. "
			})

	)


#@Target.register(NS, 'workspace', 'cmd:options')
#def rsr_workspace(prog=None, opts=None):
#	"""
#	FIXME: this should interface with taxus metastore on this host (for this user).
#	Not in use yet.
#	"""
#	ws = res.Workspace.find(prog.pwd, prog.home)
#	if not ws and opts.init:
#		ws = res.Workspace(prog.pwd)
#		if opts.force or lib.Prompt.ask("Create workspace %r?" % ws):
#			ws.init(True)
#		else:
#			print "Workspace init cancelled. "
#	if not ws:
#		print "No workspace, make sure you are below one or have one in your homefolder."
#		yield 2
#	libs = confparse.Values(dict(
#			path='/usr/lib/cllct',
#		))
#	yield Keywords(ws=ws, libs=libs)

@Target.register(NS, 'volume', 'cmd:options')
def rsr_volume(prog=None, opts=None):
	"""
	Find existing volume from current working dir, reset it, or create one in the current
	dir. Yields keyword 'volume'.

	This should interface with an local volume and its dotdir with eg. config and (standalone) indices.

	The Volume.store is a shelve storge for the primary metadata of a file.
	Besides it has indices for quick-lookup of certain property values.
	"""
	log.debug("{bblack}rsr{bwhite}:volume{default}")
	volume = res.Volume.find(prog.pwd)
	if ( volume and opts.reset ) or ( not volume and opts.init ):
		if not volume:
			volume = res.Volume(prog.pwd)
			userok = opts.force or \
					lib.Prompt.ask("Create volume %r[%s]?" % (volume.id_path,
						volume.guid))
		else:
			userok = opts.force or lib.Prompt.ask(
					"Truncate volume %r? (drops data!)" % volume)
		if userok:
			volume.init(True, opts.reset)
# XXX:
	if not volume:
		log.err("Not in a volume")
		yield 1
	# finally, change PWD
	os.chdir(volume.path)
	log.note("rsr:volume %r for %s", volume.store, volume.full_path)
	yield Keywords(volume=volume)


@Target.register(NS, 'status', 'rsr:volume')
def rsr_status(prog=None, volume=None, opts=None):
	log.debug("{bblack}rsr{bwhite}:status{default}")
	# print if superdir is OK
	#Meta.index.get(dirname(prog.pwd))
	# start lookign from current dir
	meta = res.Meta(volume)
	opts = confparse.Values(res.Dir.walk_opts.copy())
	opts.interactive = False
	opts.recurse = True
	opts.max_depth = 1
	for path in res.Dir.walk_tree_interactive(prog.pwd, opts=opts):
		if not meta.exists(path):
			yield { 'status': { 'unknown': [ path ] } }
			continue
		elif not meta.clean(path):
			yield { 'status': { 'updated': [ path ] } }
	yield 0

@Target.register(NS, 'add', 'rsr:volume')
def rsr_add(prog=None, opts=None, volume=None, args=None):
	"""
	Add files. Put records into stage-shelve.
	"""
	meta = res.Meta(volume)
	for name in args:
		yield meta.add(name, prog, opts)
	# print contents and status of stage
	yield StageReport(meta)
	# print unknown stuff
	#yield VolumeReport()


@Target.register(NS, 'update-volume', 'rsr:volume')
def rsr_update_volume(prog=None, volume=None, opts=None, *args):
	"""
	Walk all files, determine identity. Keep one ID registry per host.

See update_metafiles
	Walk all files, gather metadata into metafile.

	Create metafile if needed. Fill in 
		- X-First-Seen
	This and every following update also write:
		- X-Last-Update
		- X-Meta-Checksum
	Metafile is reloaded when
		- Metafile modification exceeds X-Last-Update
	Updates of all fields are done when:
		- File modification exceeds X-Last-Modified
		- File size does not match Length
		- If any of above mentioned and at least one Digest field is not present.

	""" 
	for path in res.Dir.walk(prog.pwd):
		if not os.path.isfile(path):
			continue
		mf = res.Metafile(path)
		mf.tmp_convert()

@Target.register(NS, 'update-metafiles', 'rsr:volume')
def rsr_update_metafiles(prog=None, volume=None, volumedb=None, opts=None):
	log.debug("{bblack}rsr{bwhite}:update-volume{default}")
	i = 0
	for path in res.Metafile.walk(prog.pwd):
		print path
		i += 1
		new, updated = False, False
		metafile = res.Metafile(path)
		#if options:
		#metafile.basedir = 'media/application/metalink/'
		#if metafile.key in volumedb:
		#	metafile = volumedb[metafile.key]
		#	#log.info("Found %s in volumedb", metafile.key)
		#else:
		#	new = True
		if metafile.needs_update():
			log.note("Updating metafile for %s", metafile.path)
			metafile.update()
			updated = True
		#if updated or metafile.key not in volumedb:
		#	log.note("Writing %s to volumedb", metafile.key)
		#	volumedb[metafile.key] = metafile
		#	new = True
		if new or updated:
			#if options.persist_meta:
			#if metafile.non_zero:
			#	log.note("Overwriting previous metafile at %s", metafile.path)
			metafile.write()
			for k in metafile.data:
				print '\t'+k+':', metafile.data[k]
			print '\tSize: ', lib.human_readable_bytesize(
				metafile.data['Content-Length'], suffix_as_separator=True)
		else:
			print '\tOK'
	volume.store.sync()

@Target.register(NS, 'meta', 'rsr:volume')
#def rsr_meta(src, pred, value, volume=None, *args):
def rsr_meta(volume=None, *args):
	"""
	Get or set specific metadata.

		/volume/dir/ # rsr:meta ./file.avi rsr:media video/speech/lecture
		/volume/dir/ # rsr:meta ./book.pdf rsr:media text/book/technical

	"""
	src = args.pop(0)
	pred = args.pop(0)
	value = args.pop(0)

	yield Arguments(args)

	vdb = volume.db

	# if exists, read, 
	# otherwise look in shelve
	mf = Metafile.fetch(src, vdb)
	# if in shelve, mf may exist and is given quick sanity check


