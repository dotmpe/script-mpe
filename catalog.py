#!/usr/bin/env python
"""Catalog helper
"""
from __future__ import print_function
__description__ = "catalog.py - "
__version__ = '0.0.4-dev' # script-mpe

from script_mpe.libhtd import *
from script_mpe.res.ck import *
from script_mpe.res.cat import *
from script_mpe.jsotk_lib import yaml_writer

# Imports the Google Cloud client library
from google.cloud import vision
from google.cloud.vision import types


__default_catalog__ = "./catalog.yaml"
__usage__ = """
Usage:
  catalog.py [-v... options] -l|list
  catalog.py [-v... options] importcks TABLES...
  catalog.py [-v... options] add FILES...
  catalog.py [-v... options] getbyname FILE
  catalog.py [-v... options] vision-labels FILE
  catalog.py [-v... options] vision-landmarks FILE
  catalog.py [-v... options] vision-annotations FILE
  catalog.py -h|--help
  catalog.py help [CMD]
  catalog.py --version

Options:
  -c FILE, --catalog FILE
                 Provide catalog to use instead of [default: %s]
                 List
  -l, --list
                 List
  --dump
                 Dont rewrite catalog but write result to stdout.
  -a CK, --algorithm CK
                 Provide algorithm for table lines at stdin, tag is
                 normally extracted from table filename.
  --verbose, -v  ..
  --quiet        ..
  -h --help      Show this usage description
  --version      Show version (%s)
""" % ( __default_catalog__, __version__, )
import os
from itertools import chain

cmd_default_settings = dict(
        verbose=1,
        # YAML opts
        pretty=True,
        ignore_aliases=True,
        output_prefix=""
    )



def cmd_list(opts):
    "List entries"
    if not opts.catalog:
        opts.catalog = Catalog(opts.flags.catalog)
    for record in opts.catalog.data:
        print(record['name'])

def cmd_add(FILES, opts):
    """
    Add name record or error on existing name
    """
    if not opts.catalog:
        opts.catalog = Catalog(opts.flags.catalog)
    for fname in FILES:
        if not os.path.exists(fname):
            opts.catalog_add_name(fname, opts)
        else:
            opts.catalog.add_file(fname, opts)
    opts.catalog.write(opts)

def cmd_getbyname(FILE, opts):
    "Return YAML record for name"
    if not opts.catalog:
        opts.catalog = Catalog(opts.flags.catalog)
    assert FILE in opts.catalog.names
    i = opts.catalog.names[FILE]
    yaml_writer(opts.catalog.data[i], sys.stdout, confparse.Values(dict(
        opts=opts )))

def cmd_importcks(TABLES, opts):
    "Import checksum table files"
    if not opts.catalog:
        opts.catalog = Catalog(opts.flags.catalog)
    new_cks = {}
    for tabfn in TABLES:
        algo = tabfn.split('.')[-1]
        if tabfn == '-':
            tab = sys.stdin
            assert opts.flags.algo, "Algo required for stdin"
            algo = opts.flags.algo
        else:
            tab = open(tabfn)

        table = res.ck.Table.read(tab, algo=algo)
        for ck, fname in table:
            if fname not in opts.catalog.names:
                if fname not in new_cks:
                    new_cks[fname] = {}
                new_cks[fname][algo] = ck

    for fname in new_cks:
        if os.path.exists(fname):
            opts.catalog.add_file(fname, opts)
        else:
            opts.catalog.add_name(fname, opts)
        for algo, ck in new_cks[fname].items():
            if not isinstance(ck, str):
                ck = " ".join(map(str, ck))
            opts.catalog.data[-1]['keys'][algo] = ck

    if opts.flags.dump:
        yaml_writer(opts.catalog.data, sys.stdout, confparse.Values(dict(
            opts=opts )))
    else:
        opts.catalog.write(opts)


def cmd_vision_landmarks(FILE, opts):
    """Detects landmarks in the file."""
    client = vision.ImageAnnotatorClient()

    with open(FILE, 'rb') as image_file:
        content = image_file.read()

    image = types.Image(content=content)
    response = client.landmark_detection(image=image)
    landmarks = response.landmark_annotations

    print('Landmarks:')
    for landmark in landmarks:
        print(landmark.description)
        for location in landmark.locations:
            lat_lng = location.lat_lng
            if not ( lat_lng.latitude and lat_lng.longitude ):
                print('No lat/long with location')
                print(lat_lng)
            else:
                print('Latitude: {}'.format(lat_lng.latitude))
                print('Longitude: {}'.format(lat_lng.longitude))


def cmd_vision_annotations(FILE, opts):
	"""
	Get all? image annotations from Vision API.
	"""
	client = vision.ImageAnnotatorClient()

	if FILE.startswith('http') or FILE.startswith('gs:'):
		image = types.Image()
		image.source.image_uri = FILE

	else:
		with open(FILE, 'rb') as image_file:
			content = image_file.read()

		image = types.Image(content=content)

	annotations = client.web_detection(image=image).web_detection

	if annotations.pages_with_matching_images:
		print('\n{} Pages with matching images retrieved'.format(
			len(annotations.pages_with_matching_images)))

		for page in annotations.pages_with_matching_images:
			print('Url   : {}'.format(page.url))

	if annotations.full_matching_images:
		print ('\n{} Full Matches found: '.format(
			   len(annotations.full_matching_images)))

		for image in annotations.full_matching_images:
			print('Url  : {}'.format(image.url))

	if annotations.partial_matching_images:
		print ('\n{} Partial Matches found: '.format(
			   len(annotations.partial_matching_images)))

		for image in annotations.partial_matching_images:
			print('Url  : {}'.format(image.url))

	if annotations.web_entities:
		print ('\n{} Web entities found: '.format(
			len(annotations.web_entities)))

		for entity in annotations.web_entities:
			print('Score      : {}'.format(entity.score))
			print('Description: {}'.format(entity.description))


def cmd_vision_labels(FILE, opts):
	"""
	Get Vision API annotator client just for labels.
	"""
	# Instantiates a client
	client = vision.ImageAnnotatorClient()

	# Loads the image into memory
	with open(FILE, 'rb') as image_file:
		content = image_file.read()

	image = types.Image(content=content)

	# Performs label detection on the image file
	response = client.label_detection(image=image)
	labels = response.label_annotations
	for label in labels:
		print(label.description)




### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug
    ))

### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    if not opts.flags.catalog: opts.flags.catalog = __default_catalog__
    opts.catalog = None
    return init

def main(opts):
    #opts.default = 'calc'
    settings = opts.flags
    if settings.list: opts.cmds = ['list']
    assert os.path.exists(opts.flags.catalog), opts.flags.catalog
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    global __version__
    return 'script-mpe:catalog.py/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    #usage = __description__ +'\n\n'+ __usage__
    usage = __description__+'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'CATALOG', __default_catalog__ ) )
    opts = libcmd_docopt.get_opts(
            usage, version=get_version(), defaults=defaults)
    sys.exit(main(opts))
