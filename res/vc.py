"""
res.vc - find version-control repositories and list contents

Python native scans to detect VC type per dir. Walk using res.fs.Dir and
ignores defined there. Using `vc` script invocations to get data already
extracted by a shell script function.
"""
import os

from script_mpe import lib, log
from fs import Dir


class Repo(Dir):

    def __init__(self, path, uri=None, rtype=None):
        assert os.path.isdir(path), path
        self.path = path
        if not rtype:
            rtype = self.__class__.get_type(path)
        self.rtype = rtype
        if not uri:
            uri = self.__class__.get_reporef(path)
        self.uri = uri

    # Static

    repo_match = (
            ".git",
            ".svn",
            ".bzr",
            ".hg"
        )

    repo_type = {
            'GIT': ['.git',],
            'Subversion': ['.svn',],
            'BazaarNG': ['.bzr',],
            'Mercurial': ['.hg',],
        }

    @classmethod
    def fetch(Klass, p=None):
        if not p:
            p = os.getcwd()
        if Klass.is_repo(p):
            return Klass(p)

    @classmethod
    def is_repo(klass, path):
        return klass.get_type(path) != None

    @classmethod
    def get_type(klass, path):
        for n in klass.repo_match:
            if os.path.exists(os.path.join(path, n)):
                for t in klass.repo_type:
                    if n in klass.repo_type[t]:
                        return t

    @classmethod
    def get_reporef(klass, path, rtype=None):
        if not rtype:
            rtype = klass.get_type(path)
        return getattr(klass, 'get_reporef_'+rtype)(path)

    @classmethod
    def get_reporef_Subversion(klass, path):
        return lib.cmd("cd %s;svn info | grep URL\: | sed 's/[^:]*\: //'" %
                path).strip()

    @classmethod
    def get_reporef_GIT(klass, path):
        r = lib.cmd("cd %s;git remote -v" % path)\
                .strip().split('\n')
        while r:
            ri = r.pop(0)
            if 'fetch' in ri:
                return ri.split('\t')[1].split(' ')[0]

    @classmethod
    def get_reporef_BazaarNG(klass, path):
        pass

    @classmethod
    def get_reporef_Mercurial(klass, path):
        pass

    @classmethod
    def walk(Klass, path, bare=False, max_depth=-1, recursive=False,
            max_repo_depth=-1, s=False):
        # XXX: maybe rewrite to Dir.walk
        """
        Walk all paths, yield basedirs which have version-control metadir.
        The Repo.repo_type attribute maps the directory names to VCS
        description, for all the types that this method `walk` can detect.

        `max-depth` is -1 default, to disregard path depth and to recurse into
        as many directories as are found.

        To include sub-repositories, set `recurse`. `max-repo-depth` now
        acts similarly to `max-depth`.
        """
        assert not bare, 'TODO: not implemented, include .git bare dirs?'
        assert not recursive, 'TODO: not implemented'
        assert -1 == max_repo_depth, 'TODO: not implemented'
        repo_stack = []
        for root, nodes, leafs in os.walk(path):

            # Dirs
            for node in list(nodes):
                dirpath = os.path.join(root, node)
                if not os.path.exists(dirpath):
                    if not s: log.err("Error: reported non existant node %s", dirpath)
                    nodes.remove(node)
                    continue
                depth = dirpath.replace(path,'').strip('/').count('/')
                if Dir.ignored(dirpath):
                    if not s: log.err("Ignored directory %r", dirpath)
                    nodes.remove(node)
                    continue
                elif max_depth != -1:
                    if depth >= max_depth:
                        nodes.remove(node)
                        continue
                if Klass.is_repo(dirpath):
                    if recursive:
                        if len(repo_stack) == max_repo_depth:
                            # Dont recurse dir which is tracked by VC system
                            nodes.remove(node)
                    else:
                        nodes.remove(node)
                    yield dirpath

    def excluded(self):
        """List both unversioned and ignored"""
        lines = lib.cmd('vc ufx', cwd=self.path, allowerrors=True, allowempty=True)
        return [ os.path.join(self.path, l) for l in lines.split('\n') if
                l.strip() ]

    @classmethod
    def walk_excluded(Klass, path, **kwds):
        return Klass.walk_untracked(path, include_excluded=True, **kwds)

    def untracked(self):
        """List unversioned files"""
        lines = lib.cmd('vc uf', cwd=self.path, allowerrors=True, allowempty=True)
        return [ os.path.join(self.path, l) for l in lines.split('\n') if
                l.strip() ]

    @classmethod
    def walk_untracked(Klass, path, include_excluded=True, ignore_symlinks=True,
            ignore_basesymlinks=False, s=False):
        """
        With `untracked` on, instead yield all files not tracked by any VCS.
        If `excluded` is on, return existing files ignored by VCS as well.

        TODO: Lots of symlink handling may be needed. Added ignore_symlinks,
        but for leafs only.
        If ignore_basesymlinks is on, symlinks outside root are ignored too.

        Maybe hook in with symlinks.tab, but others too. Global excludes
        should be done in fs.{File,Dir} btw. Boils down to 1. Dir.walk filters
        and 2. CLI parameterization. With filters and transforms, can then
        rewrite these Repo.walk_* routines.

        Are symlinks to paths under version control ok? Shall we ignore other
        known metadirs? Iow. some of both name pattern and other stat-info
        filter config management.
        """

        repos = []
        for root, nodes, leafs in os.walk(path):

            # Dirs
            for node in list(nodes):
                dirpath = os.path.join(root, node)
                if os.path.islink(dirpath):
                    dirpath = os.path.realpath(dirpath)
                    if ignore_basesymlinks and not dirpath.startswith(root):
                        pass
                if Repo.is_repo(dirpath):
                    repos.append((root, dirpath))
                    nodes.remove(node)

            # Other path names
            for leaf in list(leafs):
                leafpath = os.path.join(root, leaf)
                if os.path.islink(leafpath):
                    if ignore_symlinks:
                        continue
                    realpath = os.path.realpath(leafpath)
                    if Repo.is_repo(realpath):
                        repos.append((root, realpath))
                        continue
                    elif not os.path.exists(realpath):
                        if not s: log.stderr("Warning: broken symlink %s", leafpath)
                yield leafpath

        repos = sorted(set(repos))

        for rootdir, repodir in repos:
            try:
                repo = Repo(repodir)
            except Exception as e:
                if not s: log.stderr("Error in %s" % repodir + str(e))
                continue
            if include_excluded:
                for p in repo.excluded():
                    yield p
            else:
                for p in repo.untracked():
                    yield p

    def filetype_histogram(self):
        """
        Return a 'histogram' of file types; count instances for each file extension.
        """
        lines = lib.cmd('vc tracked-files', cwd=self.path, allowerrors=True, allowempty=True)
        counts = {'(total)':len(lines)}
        for l in lines.split('\n'):
            if not l.strip(): continue
            _, ext = os.path.splitext(l)
            if ext not in counts:
                counts[ext] = 0
            counts[ext] += 1
        return counts
