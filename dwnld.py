#!/usr/bin/env python
"""
TODO
	Find metadata storage on OS X.
"""
import os
import urllib2
try:
	from md5 import md5
except ImportError:	
	from hashlib import md5


entity_headers = (
		'Allow',
		'Expires',
		'Last-Modified',
		'Content-Encoding',
		'Content-Type',
		'Content-Location',
		'Content-Length',
		'Content-Language',
		'Content-MD5'
)
metasuffix = '.head'
timefmt = '%a, %d %b %Y %H:%M:%S GMT' # http time format
default_index = '.default'
query_hash_prefix = '/#refmd5:'
literal_types = [
		'text/*', 
		'application/xml',
		'application/xhtml+xml'
		]


def absolutize(ref, baseref):

	p = ref.find(':')
	if p and ref[p:p+2] == '://':
		return ref # already absolute ref

	if baseref[-1] != '/': # base may be a neighbour
		p = baseref.rfind('/')
		if p:
			baseref = baseref[:p+1]

	if '/' in ref:
		if '..' in ref:
			pass # TODO

		p = ref.rfind('/')
		if p:
			ref = ref[p+1:]

	return baseref + ref


def get_target_path(requri, options):

	scheme, auth, path, param, query, frag = urlparse.urlparse(requri)

	# (Net)path
	if options.wget_path:
		if not options.no_domain:	
			p = auth.find('@')
			if p:
				auth = auth[p+1:]
			#p = auth.find(':')
			#if not p:
			#	auth += ':80'
			target = (auth + path).replace('/', os.sep)
		else:
			target = path[1:]
	else:
		target = os.path.basename(path[1:])

	if target.endswith('/'):
		target += options.directory_default

	if options.directory:
		target = os.path.join(options.directory, target)

	# Query
	if query:
		if options.query_hash:
			target += options.query_hash_prefix + md5(requri).hexdigest()

		elif not options.no_query:
			target += '?'+ query

	# Duplicate downloads
	if options.no_overwrite:
		if os.path.exists(target):
			copy = 1
			while os.path.exists(target +'.%i' % copy ):
				copy += 1
			target = target + '.%i' % copy

	return target			


def mkdirs(path):

	dir = os.path.dirname(path)
	if dir and not os.path.isdir(dir):
		if not os.path.isfile(dir):
			mkdirs(dir)
		os.mkdir(dir)


def match_media(mediatype, types=literal_types):
	print 'TODO: filter'
	return False


def scan_text_for_uriref(filename):
	print 'TODO: recurse'
	return []


def download(uriref, target, options, metafile=None, metaheaders=entity_headers):

	print 'Downloading %s' % uriref
	fl = urllib2.urlopen(uriref)

	headers = fl.info()
	entity = {}
	for hd in entity_headers:
		if hd in headers:
			if hd == 'Content-Location':
				entity[hd] = absolutize( headers[hd], uriref )
				if options.update_location:
					uriref = entity[hd]
					target = get_target_path( uriref, options )
					metafile = target + options.metasuffix
				continue	

			entity[hd] = headers[hd]

	if 'Content-Location' not in entity:
		entity['Content-Location'] = uriref

	mkdirs(target)

	open(target, 'w').write(fl.read())

	if not metafile:
		metafile = target + options.metasuffix

	open(metafile, 'w').writelines([ "%s: %s\r\n" % e for e in
		entity.items() ])

	# TODO
	#if 'Last-Modified' in headers:
	#	timestamp = ''
	#elif 'Date' in headers:
	#	timestamp = ''

	#mtime = calendar.timegm(time.strptime(time, timefmt))
	#os.utime(target, (mtime, mtime))
	#os.utime("%s.head" % target, (mtime, mtime))

	print 'Wrote %s to %s' % (uriref, target)

	return uriref, target


def fetch(requri, target, options):

	if options.name:
		target = os.path.join(options.directory, options.name)
	
	elif not target:
		# automatic path
		target = get_target_path(requri, options)

	metaheaders = ()
	if options.metadata:
		metaheaders += entity_headers
	if options.headers:
		metaheaders += options.headers

	metafile = target + options.metasuffix

	requri, target = download(requri, target, options, metaheaders=metaheaders, metafile=metafile)

	if options.recurse:
		metafile = target + options.metasuffix

		for line in open(metafile, 'r').readlines():
			sep = line.find(':')
			name, value = line[:sep].strip(), line[sep+1:].strip()
			if name == 'Content-Type':
				if match_media(value, literal_types):
					for ref in scan_text_for_uriref(target):
						yield ref


if __name__ == '__main__':
	import optparse, urlparse

	parser = optparse.OptionParser()

	# Target location
	parser.add_option('-n', '--name', type='string', help='Save contents under name.')
	parser.add_option('-d', '--directory', type='string', default=os.curdir, 
			help='Write to file in directory (%default)')
	parser.add_option('-u', '--update-location', action='store_true', help='Adjust '
			'target location once Content-Location header has been received.')
	parser.add_option('-r', '--recurse', action='store_true', help='Scan literal content for '
			'references and recurse.')
	parser.add_option('-l', '--literal-types', action='append',
			metavar='string', default=literal_types, help='Provide additional '
			'MIME types for data interpreted as text.')

	# Metadata file
	parser.add_option('-m', '--metadata', action='store_true', help='Store '
			'entity headers as metadata, to pick specific headers use --headers.')
	parser.add_option('--headers', metavar='STR', action='append', 
			help='Store these headers into metadata.')
	parser.add_option('--metasuffix', type='string', default=metasuffix,
			help='Suffix to use for metadata file (%default).')
	parser.add_option('-p', '--wget-path', action='store_true', help='Duplicate'
			' server path, starting at domain (like wget -r). Overrides --name.')
	parser.add_option('--no-domain', action='store_true', help='Implies '
			'--wget-path, but start at path, disregarding domain/port.')

	# Automatic filename/path
	parser.add_option('--no-query', action='store_true', help='Do not include '
			'query part in automatic filename.')
	parser.add_option('--query-hash', action='store_true', help='Replace '
			'query part with MD5 hash of the complete URI reference. Overrides '
			'--no-query')
	parser.add_option('--query-hash-prefix', default=query_hash_prefix, type='string',
			help='Prefix used for hash in --query-hash.')
	parser.add_option('--no-overwrite', action='store_true', help='Autonumber subsequent downloads')
	parser.add_option('--directory-default', default=default_index,
			help='Default leaf to store directory entities (paths with no filename) (%default)')


	options, arguments = parser.parse_args()

	if not arguments:
		parser.error('Requires at least one request URI')

	fetchuris = arguments

	while fetchuris:
		requri = fetchuris.pop()
		for ref in fetch(requri, None, options):
			fetchuris.append(ref)


