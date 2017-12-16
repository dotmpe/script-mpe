#!/usr/bin/env python

from __future__ import with_statement, print_function

import os
import sys
import errno

from fuse import FUSE, FuseOSError, Operations


class ProjectDirFS(Operations):

    """
    """

    def __init__(self, root):
        self.root = root

#
