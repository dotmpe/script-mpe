#!/usr/bin/env python
"""
:Created: 2017-06-25
:Updated: 2017-12-26

Commands:
  - into | stats
"""
from __future__ import print_function

__description__ = "photos - photos folder management"
__short_description__ = "Photos folder management"
__version__ = '0.0.4-dev' # script-mpe
__couch__ = 'http://localhost:5984/the-registry'
__db__ = '~/.photos.sqlite'
__osx_photos_folder__ = "~/Photos/Photos Library.photoslibrary"
__photos_folder__ = "~/Photos"
__usage__ = """
Usage:
  photos.py [options] (update) [NAME]
  photos.py [options] info | init | stats | clear
  photos.py help [CMD]
  photos.py -h|--help
  photos.py --version

Options:
  -d REF, --dbref=REF
                SQLAlchemy DB URL [default: %s] (sh env 'HIER_DB')
  --no-db       Don't initialize SQL DB connection or query DB.
  --couch=REF
                Couch DB URL [default: %s] (sh env 'COUCH_DB')
  --auto-commit
  --photos-folder DIR
                [default: %s] (shell env. 'PHOTOS_FOLDER')
  --interactive
                Prompt to resolve or override certain warnings.
                XXX: Normally interactive should be enabled if while process has a
                terminal on stdin and stdout.
  --batch
                Overrules `interactive`, exit on errors or strict warnings.
  --commit
                Commit DB session at the end of the command [default].
  --no-commit
                Turn off commit, performs operations on SQL Alchemy ORM objects
                but does not commit session.
  --dry-run
                Implies `no-commit`.
  --print-memory
                Print memory usage just before program ends.
  -v            Increase verbosity.
  --verbose     ..
  --quiet       ..
  -h --help     Show this usage description.
                For a command and argument description use the command 'help'.
  --version     Show version (%s).

""" % ( __db__, __couch__, __photos_folder__, __version__, )

from datetime import datetime
import os
import re
import hashlib

from script_mpe.libhtd import *
from script_mpe.taxus import core, img


models = [ core.ID, core.Tag, core.Topic, img.Photo ]

ctx = Taxus(version='photos')

cmd_default_settings = dict(verbose=1,
        commit=True,
        session_name='default',
        print_memory=False,
        all_tables=True, # FIXME
        database_tables=False
    )



# were all SQL schema is kept. bound to engine on get_session
SqlBase = model.SqlBase


def img_exif_load(img):
    try:
        return piexif.load(IMG)
    except ValueError as e:
        print("Failing reading exif for %s" % IMG, file=sys.stderr)
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
    print('TODO')


def cmd_stats(g):
    global ctx
    db_sa.cmd_sql_stats(g, sa=ctx.sa_session)


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug,
        info = db_sa.cmd_info,
        init = db_sa.cmd_init,
        clear = db_sa.cmd_reset
))


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    opts.flags.update(dict(
        dbref = ScriptMixin.assert_dbref(opts.flags.dbref),
        photos_folder = os.path.expanduser(opts.flags.photos_folder),
        commit = not opts.flags.no_commit and not opts.flags.dry_run,
        interactive = not opts.flags.batch,
        verbose = not opts.flags.quiet
    ))
    if not opts.flags.interactive:
        if os.isatty(sys.stdout.fileno()) and os.isatty(sys.stdout.fileno()):
            opts.flags.interactive = True

    return init

def main(opts):

    """
    Execute using docopt-mpe options.
    """
    global ctx, commands

    ctx.settings = settings = opts.flags
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'photos.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf-8')

    db_sa.schema = sys.modules['__main__']
    db_sa.metadata = SqlBase.metadata

    usage = __description__ +'\n\n'+ __short_description__ +'\n'+ \
            libcmd_docopt.static_vars_from_env(__usage__,
        ( 'PHOTOS_DB', __db__ ),
        ( 'PHOTOS_FOLDER', __photos_folder__ ),
        ( 'COUCH_DB', __couch__ ) )

    opts = libcmd_docopt.get_opts(__usage__, version=get_version(),
            defaults=defaults)
    opts.flags.dbref = taxus.ScriptMixin.assert_dbref(opts.flags.dbref)
    sys.exit(main(opts))
