#!/usr/bin/env python
"""
Take a set of paths and assert that each real location is an archived path.
Move files and symlink to archive root if needed. 

Exceptions are when the files
are either too old or too large.
"""
import os, sys, re, fnmatch, datetime, optparse, itertools

import confparse


config = confparse.get_config('cllct.rc')
"Root configuration file."

settings = confparse.yaml(*config)
"Static, persisted settings."


# Settings with hard-coded defaults

volumes = settings.rsr.volumes#.getlist([ '%(home)/htdocs/' ])
"Physically disjunct storage trees."

archive_root = settings.archive.root#.getstr('%(volumes)')
"Root for current archive."

archived = settings.volumes.archives#.getlist([])
"Roots of older archives."

archive_sep = settings.archive.separator#.getstr(os.sep)
"Used in auto-generated archive paths."

archive_format = settings.archive.format#.getstr(
#        '%%(year)s%(archive.separator)s%%(month)#20s%(archive.separator)s%%(day)#20s')
archive_format = os.sep.join((
    '%(year)#04i', '%(month)#02i', '%(day)#02i'))
"Archive part of auto-generated paths."


#settings.rsr.exclude.getlist([])


# Dynamic values

root_volume = settings.default.volume#.getstr

minimum_age = settings.archive.minimum_age#.getint('0')
maximum_age = settings.archive.maximum_age#.getsec('3 days')

minimum_size = settings.archive.minimum_size#.getint('1')
maximum_size = settings.archive.maximum_size#.getsize('10MB') # 1024**3


# Command-line frontend

usage_descr = "%archive [options] paths"

long_descr = __doc__

options_spec = (
    ('--min-age', {'default': minimum_age, 'help':
        "The minimum age to put in the cabinet, %default seconds by default. " }),
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

# see rgrep params of that name
    ('--exclude-dir', {'action':'append'}),
    ('--exclude-from', {}),
    ('--exclude', {'action':'append'}),

    ('--clear-exclude-dirs', {}),
    ('--clear-exclude', {}),

    (('-n', '--no-act'), {'default':False,'action':'store_true'}),
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
                    log(action, "Ignored %s in <%s>", part, path)
            else:
                if len(part) == 1:
                    part = '0'+part
                if not month:
                    if not (0 < int(part) <= 12):
                        log(action, "Illegal month number %s after year %s <%s>",
                            part, year, path)
                    month = part
                else:
                    if not (0 < int(part) <= 31): 
                        log(action, "Illegal day number %s for %s-%s <%s>",
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
    datetuple = map(int,str(datetime.date.fromtimestamp(
            os.stat(path).st_mtime)).split('-'))
    date = dict(itertools.izip(
            ('year','month','day'), datetuple))

    ro = 0
    if not root.startswith('.'):
        ro = len(root)
    newpath = os.path.join(archive_root, 
            archive_format % date,
            path[ro:])

    if not settings.rsr.no_act:
        assert os.path.exists(path), path
        assert os.path.isfile(path), path
        target_dir = os.path.dirname(newpath)
        print path, newpath, target_dir
        if not os.path.exists(target_dir):
            os.makedirs(target_dir)
        os.rename(path, newpath)
    else:
        log(debug, 'Toarchive %s -> %s', path, newpath)
    #os.path.rename(path, newpath)
    #os.path.symlink(path, newpath)


system, debug, info, action, warning, error = range(0,6)
CHATTER = 1

def log(level, msg, *args):
    print >>sys.stderr, msg % args


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
                    log(warning, 'Illegal characters in %s', cpath)
                elif os.path.isfile(cpath):
                    skip = 0 > os.path.getsize(cpath) > maxsize
                    if skip:
                        log(action, 'Skipping: too large: %s', cpath)

            if skip:
                log(action, 'Ingored %s', cpath)
                if os.path.isdir(cpath):
                    dirs.remove(name)
                else:
                    files.remove(name)

            if not os.path.isdir(cpath):
                if not isarchive(cpath):
                    archive(cpath, path, settings.archive.root)
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

    settings.rsr.no_act = opts.no_act

    if not args:
        args = [os.getcwd()]
        log(action, "Running from: %s", args[0])

    for path in args:
        if not os.path.exists(path):
            log(warning, "Path does not exist: %s", path)
        else:
            archive_recursive(path)


