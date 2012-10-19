from fnmatch import fnmatch
import os

import confparse
import log
from lib import Prompt


class File(object):

    ignore_names = (
            '._*',
            '.crdownload',
            '.DS_Store',
            '*.swp',
            '*.swo',
            '*.swn',
            '.git*',
        )

    ignore_paths = (
            '*.pyc',
            '*~',
            '*.part',
            '*.incomplete',
        )

    @classmethod
    def ignored(klass, path):
        for p in klass.ignore_paths:
            if fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
            if fnmatch(name, p):
                return True


class Dir(object):

    ignore_names = (
            '._*',
            '.metadata',
            '.conf',
            'RECYCLER',
            '.TemporaryItems',
            '.Trash*',
            'cllct',
            '.cllct',
            'System Volume Information',
            'Desktop',
            'project',
            'sam*bup*',
            '*.bup',
            '.git*',
        )

    ignore_paths = (
            '*.git',
        )

    @classmethod
    def ignored(klass, path):
        for p in klass.ignore_paths:
            if fnmatch(path, p):
                return True
        name = os.path.basename(path)
        for p in klass.ignore_names:
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

    walk_opts = confparse.Values(dict(
        interactive=False,
        recurse=False,
        max_depth=-1,
    ))
    @staticmethod
	def walk(Klass, path, opts=walk_opts):
        if opts.max_depth > 0:
            assert opts.recurse
        for root, dirs, files in os.walk(path):
            for node in list(dirs):
                if not opts.recurse and not opts.interactive:
                    dirs.remove(node)
                    continue
                dirpath = os.path.join(root, node)
                if not os.path.exists(dirpath):
                    log.err("Error: reported non existant node %s", dirpath)
                    dirs.remove(node)
                    continue
                depth = dirpath.replace(path,'').strip('/').count('/')
                if Klass.ignored(dirpath):
                    log.err("Ignored directory %r", dirpath)
                    dirs.remove(node)
                    continue
                elif opts.max_depth != -1 and depth >= opts.max_depth:
                    dirs.remove(node)
                    continue
                elif opts.interactive:
                    log.info("Interactive walk: %s",dirpath)
                    if not Klass.prompt_recurse(opts):
                        dirs.remove(node)
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
                filepath = os.path.join(root, leaf)
                if not os.path.exists(filepath):
                    log.err("Error: non existant leaf %s", filepath)
                    continue
                if os.path.islink(filepath) or not os.path.isfile(filepath):
                    log.err("Ignored non-regular file %r", filepath)
                    continue
                if File.ignored(filepath):
                    #log.err("Ignored file %r", filepath)
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

