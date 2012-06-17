"""
"""
import os, sys, re, anydbm

import txs
import log
from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
    Target 



NS = Namespace.register(
    prefix='lnd',
    uriref='http://project.dotmpe.com/script/#/cmdline.Lind'
)

Options.register(NS, )

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
        for root, dirs, files in os.walk(pwd.location.path):
            for name in files + dirs:
                log.info("{bblack}Typing tags for {green}%s{default}",
                        name)
                path = FS_Path_split(os.path.join(root, name))
                for tag in path:
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


