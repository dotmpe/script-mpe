#!/usr/bin/env python
"""
basename-reg: split filename from known extensions

current impl. allows concatenation of var. tags, known and unknown

TODO: should determine which tag identifies current format
other tags may participate in format, or not

config: ~/.basename-reg.yml

ie. mysql.bz2
or tar.gz

::

	runtime:
		file -> basename, *ext

		*ext-type -> enum( archive, compression, format )

	storage:
		mime-ext-reg:
			ext -> mime
		ext-map:
			ext -> ext
		multi:
			ext -> *ext
		mime-xref:
			mime -> *ext, mtype, descr
		wild xref:
			mime -> *ext, descr
			ext -> *mime


"""
from __future__ import print_function
import os

import ruamel.yaml as yaml

from script_mpe.libhtd import *


TODO_REG = {
		'py': "Python source script",
		'pyc': "Compiled Python script",
		'rst': "Restructuredtext document",
		'sh': "Shell script",
		'htm': "HTML document",
		'html': "HTML document",
		'xm': "eXtended Module Tracker music document",
		'js': "Javascript script",
		'exe': "MS executable",
		'zip': "ZIP compressed file archive",
		'csv': "Comma-Separated Values",
		'iso': "CD-ROM Image in ISO 9660 format",
		'bz2': "Bzip2 compressed file",
		'it': "Impuse Tracker music document",
		'tar': "Unix file archive",
		'gz': 'Gzip compressed file',
		'dmg': 'Mac OS Image',
		'rc': 'Executable configuration',
		'ini': 'MS-DOS-style Static configuration',
		'pdf': 'Portable Document Format',
		'pde': 'Processing Development Environment source file',
		'ino': 'Arduino C++ source file',
		'jar': 'Oracle Sun JAVA archive file',
		'mod': 'Module Tracker music document',
		'doc': 'MS Word document',
		'part': 'Partial download',
		'hex': 'Binary image file in HEX format',
		'c': 'C source-code file',
		'docx': 'ZIP Compressed MS Word XML file archive',
		'xlsx': 'ZIP Compressed MS Excel XML file archive',
		'jpg': 'Joint Photographic Expert Group',
		'nbm': 'Netbeans Plugin',
		'xml': 'eXtensible Markup Language',
		'skp': 'Sketchup Drawing',
		's3m': 'Scream Tracker 2 tracker module music file',
		'rb': 'Ruby source file',
		'rar': 'RAR compressed file archive',
	}


conf = None
fullname = None

def load_config():
	global conf, fullname
	fullname = os.path.expanduser(CONFIG)
	conf = yaml.load(open(fullname))
	if conf == CONFIG:
		print("Failed loding config. ")
	elif not conf:
		conf = {}
    #if not conf:
	if 'ext_map' not in conf:
		conf['ext_map'] = {}
		conf['mime_ext_reg'] = {}
		conf['multi'] = {}
		conf['mime_xref'] = {}
		conf['wxref'] = {}
		conf['ftype'] = []
        #conf = CONFIG_DEFAULT.copy()
		save_config()

def save_config():
	global conf, fullname
	fl = open(fullname, 'rw+')
	yaml.dump(conf.todict(), fl)
	fl.close()


class BasenameOut:
	"""Quick and dirty facade to handle output formatting. """
	emitters = dict(
		emit_known_extension = ('argument basename extension mime exts ftype description'.split(' ')),
		emit_new_extension_known_mime = ('argument basename extension mime exts ftype description'.split(' ')),
		emit_mime_detect = ('argument basename extension mime description exts'.split(' '))
	)
	def __init__(self, opts, stdout, stderr):
		self.stdout = stdout
		self.stderr = stderr
		self.templates = {}
		self.opts = opts
		fmt = opts.output_format
		#self.err("Output format %s" % fmt)
		if fmt == 'rst':
			self.init_rst_out()
		elif fmt == 'tab':
			self.init_fields_out('\t', opts.quote)
		elif fmt == 'csv':
			self.init_fields_out(opts.field_separator, opts.quote)
		elif fmt == 'brief':
			self.init_brief_out()
	def init_brief_out(self):
		self.templates['emit_mime_detect'] = "%(basename)s"
	def init_rst_out(self):
		self.templates['emit_mime_detect'] = ""
	def init_fields_out(self, sep, quote):
		opts = self.opts
		t = quote and '"%%(%s)s"' or "%%(%s)s"
		# XXX: override emitters from command-line (static), perhaps always send all
		# fields to emitter and decide wether to print later, on _emit.
		#if self.opts.output_format == 'tab':
#		self.emitters['emit_known_extension'] = ["mime", "ext"]#.split(' ')
		for emitter, fields in self.emitters.items():
			to_format = fields
			#if opts.brief and 'basename' in fields:
			#	to_format = ["basename"]
#			if opts.mime:
#				if 'mimes' in fields and 'mimes' not in to_format:
#					to_format.append('mimes')
#				if 'mime' in fields and 'mime' not in to_format:
#					to_format.append('mime')
#			if opts.extension:
#				if 'exts' in fields and 'exts' not in to_format:
#					to_format.append('exts')
#				if 'ext' in fields and 'ext' not in to_format:
#					to_format.append('ext')
			self.templates[emitter] = sep.join([ t % f for f in to_format ])
			log.debug("Emitter %s, %r", emitter, self.templates[emitter])
			setattr(self, emitter, self.emitter(emitter, fields))
	def err(self, out):
		if out:
			print(out, file= self.stderr)
	def emitter(self,emitter, fields):
		def _emit(*values):
			mapping = dict(zip( fields, values ))
			if self.opts.print_header:
				print("#", ", ".join(fields))
			if 'exts' in mapping:
				mapping['exts'] = self.opts.ext_sep.join(mapping['exts'])
			if 'mimes' in mapping:
				mapping['mimes'] = self.opts.mime_sep.join(mapping['mimes'])
			lineout = self.templates[emitter] % mapping
			if lineout:
				print(lineout, file=self.stdout)
		return _emit


### Options

usage_descr = """%prog [-bem] [options] [file1...]"""

#def optparse_bool(option, optstr, value, parser, new_value):
#	parsed_value = new_value.lower() in "1 y yes true on".split(' ')
#	#new_value.lower() in "0 n no false off".split(' ')
#	setattr(parser.values, option.dest, new_value)

def optparse_output_format(option, optstr, value, parser, new_value):
#	if new_value == 'tab':
#		values.
	setattr(values, dest, value)





class Basename(libcmd.SimpleCommand):

    NAME = 'basename'
    DEFAULT_RC = os.path.expanduser('~/.basename-reg.yaml')
    DEFAULT_CONFIG_KEY = None
    DEFAULT = ['run']

    @classmethod
    def get_optspec(Klass, inheritor):
        return (

	(( '--print-header', ), {'help':
		"", 'default': False, 'action': 'store_true' }),

# TODO: find a sane way to automatically add extensions
#	(('-a', '--'), {'help':
#		"Add unknown extension for known MIME. ", 'default': False }),
#	(('-A', '--'), {'help':
#		"Add unknown extension and MIME. Warning: this most certainly gives corrupt meta database. "
#		"Only use this for predictable, controlled data. ",
#		'default': False }),

	(('-O', '--output-format'), {'help':
		"Format for ouput, default is with csv"
		"seperated fields. Others: csv, rst. ",
#		'action': 'callback',
#		'callback': optparse_output_format,
		'default': 'tab'}),
	(('-F', '--field-separator'), {'help':
		"For CSV, this can provide an alternate separator to ','. "
		"Setting this for other formats has not effect",
		'default': ','}),
	(('--quote',), {'help':
		"The default is to quote all fields. ",
#		'action': 'callback',
#		'callback': optparse_bool,
		'default': False
	}),
	(('--mime-sep',), {'help':
		"Set sub-field separator for multi mime types. ",
		'default': ' '}),
	(('--ext-sep',), {'help':
		"Set sub-field separator for multi extensions. ",
		'default': ','}),

	(('-b', '--brief'), {'help':
		"Reset field list to basename only. ",
		'action': 'store_true',
		'default': False
		}),
	(('-m', '--mime'), {'help':
		"List MIME types. ",
		'action': 'store_true',
		'default': False }),
	(('-e', '--extension'), {'help':
		"List extensions. ",
		'action': 'store_true',
		'default': False }),

#	(('-B', ), {'help':
#		"Remove basename from output fields. ", 'default': False }),

        )

    def run(self, prog, opts, settings, *args):
        root = prog.pwd
        global fullname
        fullname = prog.config_file

        import sys
        out = BasenameOut(opts, sys.stdout, sys.stderr)

        if 'ftype' not in settings:
            log.warn('No file types loaded %s' % fullname)
            return 1
        ftypes = [ t.title() for t in settings.ftype ]

        store_mime = None
        for a in args:
            n = a
            # look for names with '.' separated fields
            if '.' not in a:
                log.warn('Ignored %s' % a)
                #out.err('Ignored %s' % a)
                continue

            """
            name_parts, candidates = scan_fields(a, opts)

            unknown = []
            for ext in extensions:
                if known(ext, opts):
                    pass
                else:
                    unknown.append(ext)

            if unknown:
                if opts.interactive:
                    try_magic(a, opts)
                elif not opts.quiet:
                    out.err("Error: unknown extensions: .%s" % '.'.join(exts))
    """
            # treat each field after first as potential tag, start with last
            name_parts = a.lower().split('.')[1:][::-1]
            for e in name_parts:
                if not e.strip():
                    continue
                # strip file
                # FIXME: this does not replace uppercase tags yet
                # translate tag andlookup tag in registry
                ce = e
                if ce in settings['ext_map']:
                    while ce in settings['ext_map']:
                        ce = settings['ext_map'][ce]
                # replace last occurence of tag '.e'
                n = "".join(n.rsplit('.'+e, 1))

                if ce != e:
                    out.err("Error: non-canonical extension, rename required. ")
                    continue

                if ce in settings['mime_ext_reg']:
                    # found it, print continue
                    mime = settings['mime_ext_reg'][ce]
                    #print '# XXX', ce, mime
                    exts, ftype, descr = settings['mime_xref'][mime]
                    out.emit_known_extension(a, n, ce, mime, exts, ftype, descr)

                elif not os.path.exists(a):
                    out.err("Not a real file, cannot detect MIME: %s" % a)
                    continue

                else:
                    # look for mime
                    mime = libfile.filemtype(a)
                    if mime in settings['mime_xref']:
                        # ok, have a mime, ask later wether to use it for ext
                        exts, ftype, descr = settings['mime_xref'][mime]
                        out.emit_new_extension_known_mime(a, n, ce, mime, exts, ftype, descr)
                    elif not opts.interactive:
                        log.note("Need to select ext for MIME %r, found for %s" %
                                ( mime, a))
                        continue
                    elif store_mime != 'a':
                        descr = libfile.file_brief_description(a)
                        exts = [ce]
                        out.emit_mime_detect(a, n, ce, mime, descr, exts)
                        qopts = list(settings['ftype']) + ['sKip', 'None']
                        store_mime = lib.Prompt.query("New MIME: Give type or skip (all)", qopts)
                        if store_mime >= len(ftypes):
                            continue
                        else:
                            # XXX: should have loop while fields are updated
                            mime = lib.Prompt.input("Use MIME? ", mime)
                            descr = lib.Prompt.input("Use description? ", descr)
                            ftype = ftypes[store_mime]
                            settings['mime_xref'][mime] = [exts, ftype, descr]
                            save_config()
                    else:
                        assert False
                    if e in exts:
                        if exts[0] != e:
                            cext = ext[0]
                        else:
                            cext = e
                    else:
                        assert e == ce, (e, ce)
                        # XXX
                        cext = lib.Prompt.input("Register which? %s" % mime, ce)

                    if cext in settings['mime_ext_reg']:
                        mime2 = settings['mime_ext_reg'][cext]
                        if mime != mime2:
                            out.err("Error: Conflicting mime %r" % mime)
                    else:
                        v = lib.Prompt.ask("Store new extension? %r: %s [%s]" %
                                (exts, descr, mime), "yN")
                        if v:
                            settings['mime_ext_reg'][cext] = mime
                            save_config()
                        print(v and 'OK' or 'Cancel')

if __name__ == '__main__':
    Basename.main()

"""
TODO: test

$ basename-reg -O=rst '/Volume/Disk/Folder/File name.sql.bz2'

:folder: /Volume/Disk/Folder
:basename: File Name
:format: BZip2 compressed MySQL script
:mediatype: mime1, mime2

$ basename-reg -c key value
$ basename-reg -R reg:ext:mime mime
$ basename-reg -R reg:ext:type type

$ basename-reg --sync-to-wild
# Update wild-xref index from local

"""
"""
::

    test.py.bz2 test.py bz2 application/x-bzip2 bz2 Compressed  bzip2 compressed data
    test.py.bz2 test    py  text/x-python   py  Script  a python script text executable

not really optimal output

but next::

    some_document.en_US.utf_8.txt.gz

this is awkward to express in one line, but possible with another `exts` field
but `exts` is now used to list all tags registered as extensions for a certain
mime
so this needs multiple outputs for each ext

but that does not really seem to express whats in there
looking at it from the other way around, it would be nice to have such
structured names but it requires the data. hence mimereg to continue along this line

what this should looks like is::

    some-document
        0. text/plain; charset=utf-8; lang=en-US
        1. application/gzip

XXX some normalization on the tags is shown too


emitter { name => format, subs }
emitter <- ( name, *fields )


emitter['layer'] = "%(layer.i)i. %(layer.mime_header)s)"
emitter['file'] = "%(basename)s $(layer)s", dict( layer = 'reduce:layers' )
emitter.emit('file', basename=..., layers=[ ... ])
"""
