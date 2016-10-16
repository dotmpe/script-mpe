#!/usr/bin/env python
"""cmdline -
"""
import os
import sys
import re

import zope.interface

from . import res
from . import confparse
from . import log
from . import libcmd



class Cmd(libcmd.StackedCommand):

    NAME = 'cmd'

    DEFAULT = ['stat']
    DEPENDS = {
            'stat': [],
            'symlink_tree': ['parse_options', 'load_config'],
        }

    OPTS_INHERIT = '-v', '-q'

    @classmethod
    def get_optspec(Klass, inheritor):
        p = inheritor.get_prefixer(Klass)
        return (
                p(('--symlink-tree',),libcmd.cmddict()),
            )

    def stat(self, prog, settings):
        print(self.__class__.__name__, 'stat')
        print(prog, settings)

    def symlink_tree(self, target_path, opts=None, *source_paths):
        """
        place symlink into target-path to all leafs found in source-paths
        the root of each path serves as anchor for creating links along relative paths

        --absolute instead uses the full path in the link destination
            but paths created in target will still taken from the relative
            source paths, excluding their roots.

        --include-root reverses that behaviour, and creates a target path
            including the source roots. This does not imply --absolute, even if
            that seems to make little sense.

        with relative paths it is possible these paths collide, where the order
        of paths in source-paths dictate a first-come, first-serve implementation.
        Upon walking each source path, the first found path is stored and then
        created as symlink.

        The order of the source paths given is always important, for multiple
        paths only the first source path gets linked.

        For existing target paths that are in the way these be updated only
        if they are a symlink and broken. It is an error to be resolved
        manually when existing files in target-path are in the way.

        For symlinks, some further options are given to remove/update existing
        paths in target-path. The first three of these are exclusive.
        The following two can be used with any of the above.
        The last is the only one to accept arguments and is designed to work together
        with --force-sources, but is meaningless with others.

        --force-sources does update any existing symlink that is in the way
            and pointing to within source paths, even if it is not broken.
            This can not be combined with --force-targets, which is more
            agressive to existing symlinks in target. While this will leave
            other symlinks that are in the way alone, it undoes the default
            behaviour of keeping existing links to source paths--perhaps
            resulting of other source orders.

        --clean-symlinks
        --force-targets does update any existing symlink that is in the way,
            even if not broken, regardless wether it points to something within
            source paths. This ensures every first path found in source exists
            as target. This is more agressive than --force-sources, but does leave
            other symlinks alone.

        --keep-targets does not update existing link in target even if broken, but
            simply warns about their existence. This is not overridden by --clean-all-symlinks
            or --force-clean-symlinks which now give warnings about these paths.
            This overrides other flags and gives an non-critical error when given with
            any of the above: --clean-symlinks, --force-targets and --force-sources.

        --clean-all-symlinks removes every broken symlink in target-path, regardless
            where or what destination. This can be overriden for some paths by
            --keep-targets.

        --force-clean-symlinks removes every symlink in target-path, regardless
            where or what destination. This overrides --clean-all-symlinks. This is
            overriden for some paths by --keep-targets.

        --keep-source=PATH
            Accept extra paths to regard as source in judging link cleanup. Adding paths
            will make --force-source consider more targets as valid and refrain from
            replacing them. It is an error to have this flag without --force-source.

        :system-test: 9
        """

        print('target', target_path)
        print('source', source_paths)

        for source in source_paths:
            print(source)
            for path in res.fs.Dir.walk( source ):
                # assert real-path never in target path
                print("\t", path)


if __name__ == '__main__':
    # simple
    Cmd.main()


