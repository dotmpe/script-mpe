#!/usr/bin/env python
from __future__ import print_function

from script_mpe import rsr
from script_mpe.libname import Namespace
from script_mpe.libcmdng import Targets, Arguments, Keywords, Options,\
    Target, TargetResolver

# register
from script_mpe import main


NS = Namespace.register(
        prefix='rsr',
        uriref='http://project.wtwta.org/script/#/cmdline.Resourcer'
    )

Options.register(NS,

        (('-F', '--output-file'), { 'metavar':'NAME',
            'default': None,
            'dest': 'outputfile',
            }),

        (('-R', '--recurse', '--recursive'),{
            'dest': "recurse",
            'default': False,
            'action': 'store_true',
            'help': "For directory listings, do not descend into "
            "subdirectories by default. "
        }),

        (('-f', '--force' ),{
            'default': False,
            'action': 'store_true'
        }),
        (('-r', '--reset' ),{
            'default': False,
            'action': 'store_true'
        }),

        (('-L', '--max-depth', '--maxdepth'),{
            'dest': "max_depth",
            'default': -1,
            'help': "Recurse in as many sublevels as given. This may be "
            " set in addition to 'recurse'. 0 is not recursing and -1 "
            "means no maximum level. "
            })

    )


@Target.register(NS, 'workspace', 'cmd:options')
def rsr_workspace(prog=None, opts=None):
    """
    FIXME: this should interface with taxus metastore on this host (for this user).
    Not in use yet.
    """
    ws = res.Workspace.find(prog.pwd, prog.home)
    if not ws and opts.init:
        ws = res.Workspace(prog.pwd)
        if opts.force or lib.Prompt.ask("Create workspace %r?" % ws):
            ws.init(True)
        else:
            print("Workspace init cancelled. ")
    if not ws:
        print("No workspace, make sure you are below one or have one in your homefolder.")
        yield 2
    libs = confparse.Values(dict(
            path='/usr/lib/cllct',
        ))
    yield Keywords(ws=ws, libs=libs)


@Target.register(NS, 'volume', 'rsr:workspace')
def rsr_volume(prog=None, opts=None):
    """
    Find existing volume from current working dir, reset it, or create one in the current
    dir. Yields keyword 'volume'.

    This should interface with an local volume and its dotdir with eg. config and (standalone) indices.

    The Volume.store is a shelve storge for the primary metadata of a file.
    Besides it has indices for quick-lookup of certain property values.
    """
    log.debug("{bblack}rsr{bwhite}:volume{default}")
    volume = res.Volumedir.find(prog.pwd)
    if ( volume and opts.reset ) or ( not volume and opts.init ):
        if not volume:
            volume = res.Volumedir(prog.pwd)
            userok = opts.force or \
                    lib.Prompt.ask("Create volume %r[%s]?" % (volume.id_path,
                        volume.guid))
        else:
            userok = opts.force or lib.Prompt.ask(
                    "Truncate volume %r? (drops data!)" % volume)
        if userok:
            volume.init(True, opts.reset)
# XXX:
    if not volume:
        log.err("Not in a volume")
        yield 1
    # finally, change PWD
    os.chdir(volume.path)
    log.note("rsr:volume %r for %s", volume.store, volume.full_path)
    yield Keywords(volume=volume)

if __name__ == '__main__':
    TargetResolver().main(['cmd:options'])
