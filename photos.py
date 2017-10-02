#!/usr/bin/env python
"""
"""
__description__ = "photos - "
__version__ = '0.0.4-dev' # script-mpe
__db__ = '~/.photos.sqlite'
__usage__ = """
Usage:
  photos.py [options] stats
  photos.py [options] (update) [NAME]
  photos.py -h|--help
  photos.py --version

Options:
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    -v            Increase verbosity.
    --no-commit   .
    --commit      [default: true].
    --verbose     ..
    --quiet       ..
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __db__, __version__, )
from datetime import datetime
import os
import re
import hashlib

from script_mpe import log
from script_mpe import confparse
from script_mpe import libcmd_docopt
from script_mpe import taxus
from script_mpe import libcmd
from script_mpe.res import Volumedir
from script_mpe.res.util import ISO_8601_DATETIME
from script_mpe.taxus import init as model
from script_mpe.taxus.init import SqlBase, get_session
from script_mpe.taxus.core import ID, Node, Name, Tag, Topic
from script_mpe.taxus.img import Photo

models = [ ID, Tag, Topic, Photo ]




# were all SQL schema is kept. bound to engine on get_session
SqlBase = model.SqlBase


def img_exif_load(img):
    try:
        return piexif.load(IMG)
    except ValueError, e:
        print >>sys.stderr, "Failing reading exif for %s" % IMG
    return False

def img_unid(img, exif=None):
    if exif:
        exif = img_exif_load(img)
    if 42016 not in exif['Exif']:
        return
    return exif['Exif'][42016]


def cmd_update(IMG, opts, settings):
    """
    """
    sa = Photo.get_session('default', opts.flags.dbref)
    exif = img_exif_load(IMG)
    unid = img_unid(IMG, exif)
    photo = Photo.fetch(Photo.unid == unid, _sa=sa, exists=False)
    if not photo:
        photo = Photo()
        photo.unid = unid
        sa.add(photo)
    if opts.flags.commit:
        opts.commit()


def cmd_stats(settings, opts):
    print 'TODO'



### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute using docopt-mpe options.
    """

    settings = opts.flags
    opts.flags.commit = not opts.flags.no_commit
    opts.flags.verbose = not opts.flags.quiet
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'photos.mpe/%s' % __version__

if __name__ == '__main__':
    #photos.main()
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')
    db = os.getenv( 'PHOTOS_DB', __db__ )
    # TODO : vdir = Volumedir.find()
    if db is not __db__:
        __usage__ = __usage__.replace(__db__, db)
    opts = libcmd_docopt.get_opts(__doc__ + __usage__, version=get_version())
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
