"""
Work in progress. Finish path storage in rsr first.

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

import res
import txs
import log
from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
    Target 

from res.fslayout import FS_Path_split, FSFolderLayout
from taxus.fslayout import Folder, FolderLayout



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
def lnd_layout(args=[], opts=None, sa=None, ur=None, pwd=None):
    """
    Work in progress.
    Intialize layout on current path. 

    ./main.py lnd:layout Downloads/ --recurse --non-interactive
    """
    fl = FSFolderLayout()
    while args:
        a = args.pop(0)
        assert os.path.isdir(a), "Need directories, not %s" % a
        if opts.recurse:
            for p in res.Dir.walk(a, opts=opts):
                if not os.path.isdir(p):
                    continue
                fl.add_rule(p)
        else:
            fl.add_rule(a)
    print fl
    print 'Commit?'

    for f in FolderLayout.from_trees(fl):
        print repr(f)

@Target.register(NS, 'layouts', 'cmd:pwd')
def lnd_layouts(opts=None, sa=None, ur=None, prog=None):
    """
    TODO: Scan for layouts on path.
    """
    print prog.pwd

@Target.register(NS, 'find', 'txs:session')
def lnd_find(args=None, opts=None, sa=None, ur=None):
    """
    Find layouts for pattern.
    """
    while args:
        pattern = args.pop(0)
        r = sa.query(FolderLayout)\
                .filter(FolderLayout.name.like(pattern))
        print "%s: %s" % (pattern, r.all())
    yield 0

# X

@Target.register(NS, 'tag', 'txs:pwd')
def lnd_tag(opts=None, sa=None, ur=None, pwd=None):
    """
    Experiment, interactive interface.
    Tagging.
    """
    log.debug("{bblack}lnd{bwhite}:tag{default}")
    tags = {}
    if '' not in tags:
        tags[''] = 'Root'
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


# X2

@Target.register(NS, 'ls', 'txs:session')
def lnd_ls(opts=None, sa=None, ur=None, pwd=None):
    """
    > lnd:ls .
    < Listing for ./shared (in /Volumes/archive-7)
    < <> lnd:supernode FolderLayout('archive', "'Archive' Folder Layout");
    < FolderLayout('archive')  
    <               
    < . lnd:subnode Node('partial')
    < . lnd:subnode Node('complete')
    < Found: FolderLayout('shared', "'Shared' Folder Layout"): 3 items.
    """

@Target.register(NS, 'node', 'txs:session')
def lnd_node(opts=None, sa=None, ur=None, pwd=None):
    """
    """
         


