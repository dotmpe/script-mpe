#!/usr/bin/env python
"""archive file - rewrite locator so that file is beneath archive-root,
adding a date tag.

Take a set of paths and assert that each real location is an archived path.
Move files and symlink to archive root if needed.

Exceptions are when the files
are either too old or too large.
"""
import os, sys, re, fnmatch, datetime, optparse, itertools

import confparse
from cmdline import log


config = confparse.expand_config_path('cllct.rc')
"Root configuration file."

settings = confparse.load_path(config.next())
"Static, persisted settings."


# Settings with hard-coded defaults

#volumes = settings.rsr.volumes#.getlist([ '%(home)/htdocs/' ])
#"Physically disjunct storage trees."
#
archive_root = settings.volume.cabinet.root
#archive_root = settings.rsr.volumes.archive #.getstr('%(volumes)')
"Root for current archive."
#
#archived = settings.volumes.archives#.getlist([])
#"Roots of older archives."
#
#archive_sep = settings.archive.separator#.getstr(os.sep)
#"Used in auto-generated archive paths."

#archive_format = settings.archive.format#.getstr(
#        '%%(year)s%(archive.separator)s%%(month)#20s%(archive.separator)s%%(day)#20s')
archive_format = os.sep.join((
    '%(year)#04i', '%(month)#02i', '%(day)#02i'))
"Archive part of auto-generated paths."


# Command-line frontend

usage_descr = "%archive [options] paths"

long_descr = __doc__

root_volume = settings.default.volume#.getstr

minimum_age = settings.rsr.minimum_age#.getint('0')
maximum_age = settings.rsr.maximum_age#.getsec('3 days')

minimum_size = settings.rsr.minimum_size#.getint('1')
maximum_size = settings.rsr.maximum_size#.getsize('10MB') # 1024**3

#assert settings.rsr.archive_prefix
#assert settings.rsr.exclude_dir
archive_prefix = ""

options_spec = (
    ('--min-age', {
        'dest': 'minimum_age',
        'default': minimum_age,
        'help': "The minimum age to put in the cabinet, %default seconds by default. " }),
    ('--max-age', {'default': maximum_age, 'help':
        "The maximum age to put in the cabinet is usually determined by how "
        "far back the current archive volume goes. See ``ignore-age``." }),
    ('--ignore-age', {'action': 'store_true', 'help':
        "Ingore ``min,max-age`` setting and expand and the archive by creating "
        "older archived entries." }),
    ('--min-size', {'default': minimum_size, 'help':
        "Archiving smaller files will require user confirmation or a special "
        "flag, default: %default. See ``ignore-size``." }),
    ('--max-size', {'default': maximum_size, 'help':
        "Archiving larger files will require user confirmation or a special "
        "flag, default: %default. See ``ignore-size``." }),
    ('--ignore-size', {'action': 'store_true', 'help':
        "Ignore ``min,max-size`` setting." }),
    ('--archive-root', {'default': archive_root, 'help':
        "The directory in which the ``archive-format`` is based in. " }),
    ('--archive-format', {'default': archive_format, 'help':
        "Used when autoformatting a path. " }),
    ('--archive-prefix', {'default': archive_prefix, 'help':
        "path concat. ", 'default': "archive"}),

# see rgrep params of that name
    ('--exclude-dir', {'action':'append'}),
    ('--exclude-from', {}),
    ('--exclude', {'action':'append'}),

    ('--clear-exclude-dirs', {}),
    ('--clear-exclude', {}),

    (('-n', '--no-act'), {'dest':'dry_run','action':'store_true'}),
    (('--dry-run',), {'default':False, 'action':'store_true'}),
)

# TODO: override from sys.argv

#strippath = re.compile('^[\.\/]+|[\.\/]$').sub
#splittag = re.compile('[\.\/]').split
#ignore=(
#    '/home/berend/htdocs/Makefile',
#    '/home/berend/htdocs/.Rules.iris.mk',
#    '/home/berend/htdocs/.Rules.sam.mk',
#    '/home/berend/htdocs/main.rst',
#    '/home/berend/htdocs/sysadmin.rst',
#    '/home/berend/htdocs/sysadmin.sam.rst',
#    '/home/berend/htdocs/sysadmin.iris.rst',
#    '/home/berend/htdocs/sysadmin.ariaweg.rst',
#    '/home/berend/htdocs/sysadmin.oostereind.rst',
#    '.bzr',
#    '.git',
#)
delimiter = re.compile('[\/\._\[\]\(\),\+-]')
illegal = re.compile('[\ ~:\$\&\"\'\*]')
#maxsize = 10*1024**2


def archived(path):

    """
    Read archive date from path.
    """

    dates = []
    parts = delimiter.split(path)

    year, month, day = None, None, None
    while parts:
        part = parts.pop(0)
        if part.isdigit():
            if not year:
                if len(part)==4:
                    year = part
                else:
                    log(warn, "Ignored %s in <%s>", part, path)
            else:
                if len(part) == 1:
                    part = '0'+part
                if not month:
                    if not (0 < int(part) <= 12):
                        log(note, "Illegal month number %s after year %s <%s>",
                            part, year, path)
                    month = part
                else:
                    if not (0 < int(part) <= 31):
                        log(note, "Illegal day number %s for %s-%s <%s>",
                            part, year, month, path)
                    day = part
        if year and month and day:
            dates.append((year, month, day))
            year, month, day = None, None, None
    return dates


def isarchive(path):
    return len(archived(path)) == 1


def archive(path, root=None, archive_root=None):

    #datetuple = datetime.datetime.now().timetuple()[:3]
    # or use mtime
    try:
        st = os.stat(path)
    except:
        log(warn, "Skipping unreadable %s", path)
        return
    assert st

    datetuple = map(int, str(datetime.date.fromtimestamp(
            st.st_mtime)).split('-'))
    date = dict(itertools.izip(
            ('year','month','day'), datetuple))

    ro = 0
    if not root.startswith('.'):
        ro = len(root)
    newpath = os.path.join(
            archive_root,
            settings.rsr.archive_format
            % date,
            settings.rsr.archive_prefix +
            path[ro:])

    if not settings.rsr.dry_run:
        assert os.path.exists(path), path
        assert os.path.isfile(path), path
        target_dir = os.path.dirname(newpath)
        #print path, newpath, target_dir
        if not os.path.exists(target_dir):
            os.makedirs(target_dir)
        os.rename(path, newpath)
    else:
        log(debug, 'Toarchive %s -> %s', path, newpath)
    #os.path.rename(path, newpath)
    #os.path.symlink(path, newpath)


def ignored(path):
    if os.path.isdir(path):
        name = os.path.basename(path)
        for dp in settings.rsr.exclude_dir:
            if fnmatch.fnmatch(name, dp):
                return True
    for pp in settings.rsr.exclude:
        if fnmatch.fnmatch(path, pp):
            return True


def archive_recursive(path):
    for root, dirs, files in os.walk(path):
        leafs = dirs + files
        while leafs:
            name = leafs.pop(0)
            cpath = os.path.join(root, name)

            skip = ignored(cpath)
            if not skip:
                skip = illegal.search(cpath) is not None
                if skip:
                    log(err, 'Illegal characters in %s', cpath)
                elif os.path.isfile(cpath):
                    skip = 0 > os.path.getsize(cpath) > maxsize
                    if skip:
                        log(warn, 'Skipping: too large: %s', cpath)

            if skip:
                log(note, 'Ingored %s', cpath)
                if os.path.isdir(cpath):
                    dirs.remove(name)
                else:
                    files.remove(name)

            if not os.path.isdir(cpath):
                if not isarchive(cpath):
                    archive(cpath, path, settings.volume.cabinet.root)
                else:
                    pass#archived(cpath), cpath



if __name__ == '__main__':

    prsr = optparse.OptionParser(usage=usage_descr)
    for a,k in options_spec:
        if isinstance(a, tuple):
            prsr.add_option(*a, **k)
        else:
            prsr.add_option(a, **k)
    opts, args = prsr.parse_args()

    settings.rsr.override(opts)

    if not args:
        args = [os.getcwd()]
        log(note, "Running from: %s", args[0])

    for path in args:
        if not os.path.exists(path):
            log(warn, "Path does not exist: %s", path)
        else:
            archive_recursive(path)
