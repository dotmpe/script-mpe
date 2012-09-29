"""
Abstract
--------
Maintains layouts of particular folders, and creates new ones
from template.

Introduction
------------
Filesystems are hierarchical organizations of content. There is a 
tree structured set of names or labels to recall filed contents.

Standards and conventions have evolved in the particular structures
of these trees. An agnostic view of this is implemented by [Name a class here].
"""
import os, sys, re, anydbm

import txs
import log
from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
    Target 

from taxus import FolderLayout



NS = Namespace.register(
    prefix='lnd',
    uriref='http://project.dotmpe.com/script/#/cmdline.Lind'
)

Options.register(NS, 
#localNames={
#       'find': "Return layouts that contain 'node'."
#       'layouts': "Scan for layouts at current path."
#       'layout': "Manage layouts at current path."
#}
        )

@Target.register(NS, 'layout', 'txs:pwd')
def lnd_layout(opts=None, sa=None, ur=None, pwd=None):
    pass

@Target.register(NS, 'layouts', 'txs:sesion')
def lnd_layouts(opts=None, sa=None, ur=None):
    pass

@Target.register(NS, 'find', 'txs:session')
def lnd_find(opts=None, sa=None, ur=None):
    pass


# X

@Target.register(NS, 'tag', 'txs:pwd')
def lnd_tag(opts=None, sa=None, ur=None, pwd=None):
    """
    Experiment, interactive interface.
    Tagging.
    """
    log.debug("{bblack}lnd{bwhite}:tag{default}")

    if not pwd:
        log.err("Not initialized")
        yield 1

    tags = {}
    if '' not in tags:
        tags[''] = 'Root'
    FS_Path_split = re.compile('[\/\.\+,]+').split

    log.info("{bblack}Tagging paths in {green}%s{default}",
            os.path.realpath('.') + os.sep)

    try:
        for root, dirs, files in os.walk(pwd.local_path):
            for name in files + dirs:
                log.info("{bblack}Typing tags for {green}%s{default}",
                        name)
                path = FS_Path_split(os.path.join(root, name))
                # check if path confirms to one ore more layouts,
                # and whine on partial matches
                #FolderLayout.check_for_layouts(path);
                for tag in path:
                    # The result is that new rules may be loaded to interpret
                    # the contents of the folder. 

# The ideal is that some metafile comaptible view is kept for each file. Perhaps
# at least a metafile record, or another persisted resource.

# Right now, rsr:scan contains an Metafile initialization and update walk routine.

                    # lind should do for folders
                    yield 
                    # Ask about each new tag, TODO: or rename, fuzzy match.      
                    if tag not in tags:
                        type = raw_input('%s%s%s:?' % (
                            log.palette['yellow'], tag,
                            log.palette['default']) )
                        if not type: type = 'Tag'
                        tags[tag] = type

                log.info(''.join( [ "{bwhite} %s:{green}%s{default}" % (tag, name)
                    for tag in path if tag in tags] ))

    except KeyboardInterrupt, e:
        log.err(e)
        yield 1


