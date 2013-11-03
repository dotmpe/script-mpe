import datetime
import getpass
import optparse
import os
import re
import select
import socket
import subprocess
import sys
import readline
from os.path import basename, join,\
		isdir

import log
#import confparse
#
#
#config = confparse.expand_config_path('cllct.rc')
#"Configuration filename."
#
#settings = confparse.load_path(*config)
#"Static, persisted settings."
	
hostname = socket.gethostname()
username = getpass.getuser()


RSR_NS = 'rsr', 'http://name.wtwta.nl/#/rsr'

# Util functions

rcs_path = re.compile('^.*\/\.(svn|git|bzr)$')

def is_versioned(dirpath):
	assert isdir(dirpath), dirpath
	for d in os.listdir(dirpath):
		p = join(dirpath, d)
		m = rcs_path.match(p)
		if m:
			return True

def cmd(cmd, *args):
	proc = subprocess.Popen( cmd % args,
			shell=True,
			stderr=subprocess.PIPE, stdout=subprocess.PIPE,
			close_fds=True )
	errors = proc.stderr.read()
	if errors:
		raise Exception(errors)
	value = proc.stdout.read()
	if not value:# and not nullable:
		raise Exception("OS invocation %r returned nothing" % cmd)
	return value

def get_checksum_sub(path, checksum_name='sha1'):
	"""
	Utitilize OS <checksum_name>sum command which is likely more 
	efficient than reading in files in native Python.

	Returns the hexadecimal encoded digest directly.
	"""
	pathd = path.decode('utf-8')
	data = cmd("%ssum \"%s\"", checksum_name, pathd)
	p = data.index(' ')
	hex_checksum, filename = data[:p], data[p:].strip()
	# XXX: sanity check..
	assert filename == path, (filename, path)
	return hex_checksum

def get_sha1sum_sub(path):
	return get_checksum_sub(path)

def get_md5sum_sub(path):
	return get_checksum_sub(path, 'md5')

def get_format_description_sub(path):
	format_descr = cmd("file -bs %r", path).strip()
	return format_descr

def get_mediatype_sub(path):
	mediatypespec = cmd("xdg-mime query filetype %r", path).strip()
	#mediatypespec = cmd("file -bsi %r", path).strip()
	return mediatypespec

def remote_proc(host, cmd):
	proc = subprocess.Popen(
		'ssh '+ username+'@'+host + " '%s'" % cmd,
			shell=True,
			stderr=subprocess.PIPE, stdout=subprocess.PIPE,
			close_fds=True
		)
	errresp = proc.stderr.read()
	if errresp:
		errresp = "Error: "+ errresp.replace('ssh: ', host).strip()
		raise Exception(errresp)
	else:
		return proc.stdout.read().strip()

def human_readable_bytesize(length, suffix=True, suffix_as_separator=False,
		sub=2):
	if suffix_as_separator:
		assert suffix
	fmt = "%%.%if" % sub
	if length > 1024**4:
		div = 1024 ** 4
		if suffix:
			fmt += 'T'
	elif length > 1024**3:
		div = 1024 ** 3
		if suffix:
			fmt += 'G'
	elif length > 1024**2:
		div = 1024 ** 2
		if suffix:
			fmt += 'M'
	elif length > 1024:
		div = 1024
		if suffix:
			fmt += 'k'
	else:
		div = 1
	s = fmt % (float(length)/div)
	if suffix_as_separator and not s[-1].isdigit():
		s = s[:-1].replace('.', s[-1])
	return s

# The epoch used in the datetime API.
EPOCH = datetime.datetime.utcfromtimestamp(0)


def timedelta_to_seconds(delta):
	seconds = (delta.microseconds * 1e6) + delta.seconds + (delta.days * 86400)
	seconds = abs(seconds)

	return seconds

def datetime_to_timestamp(date, epoch=EPOCH):
	# Ensure we deal with `datetime`s.
	#date = datetime.datetime.utcfromtimestamp(date)
	epoch = datetime.datetime.utcfromtimestamp(epoch.toordinal())

	timedelta = date - epoch
	timestamp = timedelta_to_seconds(timedelta)

	return timestamp

def timestamp_to_datetime(timestamp, epoch=EPOCH):
	# Ensure we deal with a `datetime`.
	epoch = datetime.datetime.utcfromtimestamp(epoch.toordinal())

	epoch_difference = timedelta_to_seconds(epoch - EPOCH)
	adjusted_timestamp = timestamp - epoch_difference

	date = datetime.datetime.utcfromtimestamp(adjusted_timestamp)

	return date

def cn(obj):
	return obj.__class__.__name__


if __name__ == '__main__':
	print get_sha1sum_sub("volume.py");

	for f in sys.argv:
		if not os.path.exists(f):
			continue
		for n, ts in (
				('c',os.path.getctime(f)),
				('a',os.path.getatime(f)),
				('m',os.path.getmtime(f)),):
			print n, timestamp_to_datetime(ts), f



# http://code.activestate.com/recipes/134892-getch-like-unbuffered-character-reading-from-stdin/
class _Getch:
	"""Gets a single character from standard input.  Does not echo to the
screen."""
	def __init__(self):
		try:
			self.impl = _GetchWindows()
		except ImportError:
			self.impl = _GetchUnix()

	def __call__(self): return self.impl()

class _GetchUnix:
	def __init__(self):
		import tty, sys

	def __call__(self):
		import sys, tty, termios
		fd = sys.stdin.fileno()
		old_settings = termios.tcgetattr(fd)
		try:
			tty.setraw(sys.stdin.fileno())
			ch = sys.stdin.read(1)
			if ch == '\x03':
				raise KeyboardInterrupt
		finally:
			termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
		return ch

class _GetchWindows:
	def __init__(self):
		import msvcrt

	def __call__(self):
		import msvcrt
		return msvcrt.getch()

getch = _Getch()

class Prompt(object):

	"""
	Static interactive templates for readline user-interaction.
	"""

	@classmethod
	def ask(clss, question, yes_no='Yn'):
		assert len(yes_no) == 2, "Need two choices, a logica true and false, but options don't match: %r" % yes_no
		yes, no = list(yes_no)
		assert yes.isupper() or no.isupper()
		#v = raw_input('%s [%s] ' % (question, yes_no))
		print '%s [%s] ' % (question, yes_no)
		v = getch()
		if not v:
			if yes.isupper():
				v = yes
			else:
				v = no
		elif v.upper() not in yes_no.upper():
			return
		return v.upper() == yes.upper()

	@classmethod
	def raw_input(clss, prompt, default=None):
		v = raw_input('%s [%s] ' % (prompt, default))
		if v:
			return v
		elif default:
			return default

	@staticmethod
	def input(prompt, prefill=''):
		readline.set_startup_hook(lambda: readline.insert_text(prefill))
		try:
			return raw_input(prompt)
		finally:
			readline.set_startup_hook()

	@staticmethod
	def create_choice(options):
		"Options must be list of strings, one capitalized unique character each"
		opts = ''
		for i, o in enumerate(options):
			for c in o:
				if c.istitle():
					assert c not in opts, c
					opts += c
					options[i] = o.replace(c, "{white}%s{blue}" % c)
		return opts

	@classmethod
	def query(clss, question, options=()):
		assert options
		origopts = list(options)
		opts = clss.create_choice(options)
		while True:
			print log.format_line('{green}%s {blue}%s {bwhite}[{white}%s{bwhite}]{default} or [?help] ' %
					(question, ','.join(options), opts))
#			v = sys.stdin.read(1)
			v = getch()
			#v = raw_input(
			#		log.format_line('{green}%s {bwhite}[{bblack}%s{bwhite}]{default} or [?help] ') 
			#		% (question, opts)).strip()
			if not v.strip(): # FIXME: have to only strip whitespace, not ctl?
				v = opts[0]
			if v == 'help'  or v in '?h':
				print ("Choose from %s. Default is %r, use --recurse option to "
					"override. ") % (', '.join(options), options[0])
			if v.upper() in opts.upper():
				choice = opts.upper().index(v.upper())
				print 'Answer:', origopts[choice].title()
				return choice



