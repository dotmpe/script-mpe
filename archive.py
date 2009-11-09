#!/usr/bin/env python
"""archive - sort and archive files and symlinks

An archived path contains numerical date notation (year, month and day). They
are accumulated into a personal archive directory.

Procedure
---------
Take a set of paths and assert that each real location is an archived path.
Move files and symlink to archive root otherwise. Exceptions are when the files
are either too old or too large.

"""
import os, re, optparse, confparse


config = list(confparse.get_config('archive'))
"Root configuration file."

settings = confparse.ini(config)
"Static, persisted settings."


# Settings with hard-coded defaults

#volumes = settings.rsr.volumes.getlist([ '%(home)/htdocs/' ])
#"Physically disjunct storage trees."

#archive_root = settings.archive.root.getstr('%(volumes)')
archive_root = os.path.expanduser('~/archive/3/cabinet')
"Root for current archive."

#archived = settings.volumes.archives([])
#"Roots of older archives."

#archive_sep = settings.archive.separator.getstr(os.sep)
#"Used in auto-generated archive paths."

#archive_format = settings.archive.format.getstr(
#        '%%(year)s%(archive.separator)s%%(month)#20s%(archive.separator)s%%(day)#20s')
archive_format = ''
"Archive part of auto-generated paths."


# Dynamic values

#root_volume = settings.default.volume.getstr

minimum_age = 0
#minimum_age = settings.archive.minimum_age.getint('0')
maximum_age = 3*24*60*60
#maximum_age = settings.archive.maximum_age.getsec('3 days')

minimum_size = 1
#minimum_size = settings.archive.minimum_size.getint('1')
maximum_size = 1024 **3
#maximum_size = settings.archive.maximum_size.getsize('10MB')


# Command-line frontend

usage_descr = "%archive [options] paths"

long_descr = __doc__

argv_descr = (
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
)


#sep = './'
strippath = re.compile('^[\.\/]+|[\.\/]$').sub
splittag = re.compile('[\.\/]').split


def archive(path):
    """
    Interactive add-to-archive.
    """

    tags = splittag(strippath('',path))

    if not os.path.exists(path):
        return
    
    ctime, mtime = os.path.getctime(path), os.path.getmtime(path)

    size = os.path.getsize(path)

    print tags
    print ctime, mtime, size


def main():
    # cmdline invocation from path
    cwd = os.getcwd()

    prsr = optparse.OptionParser(usage=usage_descr)
    for a,k in argv_descr:
        prsr.add_option(a, **k)
    # parse argv
    opts, args = prsr.parse_args()

    for path in args:
        rspath = archive(path)
        print path, rspath
        print


if __name__ == '__main__':
    main()
