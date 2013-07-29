from fnmatch import fnmatch
import os

from script_mpe import confparse
from script_mpe import log
from script_mpe.lib import Prompt


class File(object):

	ignore_names = (
			'._*',
			'.DS_Store',
			'*.swp',
			'*.swo',
			'*.swn',
			'.git*',
			'*.pyc',
			'*~',
			'*.tmp',
			'*.part',
			'*.crdownload',
			'*.incomplete',
			'*.torrent',
			'*.uriref',
			'*.meta',
			'.symlinks'
		)

	ignore_paths = (
			'.Trashes*',
			'.TemporaryItems*',
			'*.git',
			'.git*',
		)

	@classmethod
	def ignored(klass, path):
		"""
		File.ignored checks names and paths of files with ignore patterns.
		"""
		for p in klass.ignore_paths:
			if fnmatch(path, p):
				return True
		name = os.path.basename(path)
		for p in klass.ignore_names:
			if fnmatch(name, p):
				return True


class Dir(object):

	ignore_paths = (
			'._*',
			'.metadata*',
			'.conf*',
			'RECYCLER*',
			'.TemporaryItems*',
			'.Trash*',
			'*cllct/*',
			'System Volume Information/',
			'Desktop*',
			'project*',
			'sam*bup*',
			'*.bup/',
			'.git*',
			'*.git*',
		)

	@classmethod
	def init(klass, ignore_file=None, ignore_defaults=None):
		"""

		XXX
		Without calling init, Dir class works with static or run-time data only.

		Upon providing an ignore file name, both %path.paths %ignore_file.dirs
		"""
		pass

	@classmethod
	def ignored(klass, path):
		for p in klass.ignore_paths:
			if fnmatch(path, p):
				return True
		name = os.path.basename(path)
		for p in klass.ignore_paths:
			if fnmatch(name, p):
				return True

	@classmethod
	def prompt_recurse(clss, opts):
		v = Prompt.query("Recurse dir?", ("Yes", "No", "All"))
		if v is 2:
			opts.recurse = True
			return True
		elif v is 0:
			return True
		return False

	@classmethod
	def prompt_ignore(clss, opts):
		v = Prompt.query("Ignore dir?", ("No", "Yes"))
		return v is 1

	@classmethod
	def check_ignored(Klass, filepath, opts):
		#if os.path.islink(filepath) or not os.path.isfile(filepath):
		if os.path.islink(filepath) or ( not os.path.isfile(filepath) and not os.path.isdir(filepath)) :
			log.warn("Ignored non-regular path %r", filepath)
			return True
		elif Klass.ignored(filepath) or File.ignored(filepath):
			log.info("Ignored file %r", filepath)
			return True

	@classmethod
	def check_recurse(Klass, dirpath, opts):
		#if not opts.recurse and not opts.interactive:
		#	return False
		depth = dirpath.strip('/').count('/')
		if Klass.ignored(dirpath):
			log.info("Ignored directory %r", dirpath)
			return False
		elif opts.max_depth != -1 and depth+1 >= opts.max_depth:
			log.info("Ignored directory %r at level %i", dirpath, depth)
			return False
		elif opts.recurse:
			return True
		elif opts.interactive:
			log.info("Interactive walk: %s",dirpath)
			if Klass.prompt_recurse(opts):
				return True
			elif Klass.prompt_ignore(opts):
				assert False, "TODO: write new ignores to file"

	walk_opts = confparse.Values(dict(
		interactive=False,
		recurse=False,
		max_depth=-1,
	))
	
	@classmethod
	def walk_tree_interactive(Klass, path, opts=walk_opts):
		if opts.max_depth > 0:
			assert opts.recurse
		assert isinstance(path, basestring), (path, path.__class__)
		for root, dirs, files in os.walk(path):
			for node in list(dirs):
				dirpath = os.path.join(root, node).replace(path,'').lstrip('/') +'/'
				if not os.path.exists(dirpath):
					log.err("Error: reported non existant node %s", dirpath)
					dirs.remove(node)
					continue
				elif Klass.check_ignored(dirpath, opts):
					dirs.remove(node)
					continue
				elif not Klass.check_recurse(dirpath, opts):
					dirs.remove(node)
#					continue # exception to rule excluded == no yield
# caller can sort out wether they want entries to subpaths at this level
				assert isinstance(dirpath, basestring)
				try:
					dirpath = unicode(dirpath)
				except UnicodeDecodeError, e:
					log.err("Ignored non-ascii/illegal filename %s", dirpath)
					continue
				assert isinstance(dirpath, unicode)
				try:
					dirpath.encode('ascii')
				except UnicodeDecodeError, e:
					log.err("Ignored non-ascii filename %s", dirpath)
					continue
				yield dirpath
			for leaf in list(files):
				filepath = os.path.join(root, leaf).replace(path,'').lstrip('/')
				if not os.path.exists(filepath):
					log.err("Error: non existant leaf %s", filepath)
					files.remove(leaf)
					continue
				elif Klass.check_ignored(filepath, opts):
					files.remove(leaf)
					continue
				assert isinstance(filepath, basestring)
				try:
					filepath = unicode(filepath)
				except UnicodeDecodeError, e:
					log.err("Ignored non-ascii/illegal filename %s", filepath)
					continue
				assert isinstance(filepath, unicode)
				try:
					filepath.encode('ascii')
				except UnicodeEncodeError, e:
					log.err("Ignored non-ascii/illegal filename %s", filepath)
					continue
				yield filepath


