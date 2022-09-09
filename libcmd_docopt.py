"""
:Created: 2017-10-03
:updated: 2017-12-09

Simple command-line program setup with docopt.

Parse options using docopt, use data as a optparse.Values alike.
And match arguments and options with e.g. command handler function signature
arguments by name getting for function arguments.
"""
from __future__ import print_function
import os
import sys
import inspect
import resource

import docopt

from script_mpe import lib
from script_mpe import confparse
from script_mpe import log


def defaults(opts, init={}):
    global select_kwdargs_defaults
    opts.flags.update(select_kwdargs_defaults)
    return init

def get_opts(docstr, meta={}, version=None, argv=None, defaults=defaults):
    """
    Get docopt dict, and set argv and flags from get_optvalues.
    """
    if argv == None:
        argv = sys.argv[1:]
    pattern, collected = docopt.docopt(docstr, argv, version=version,
            return_spec=True)
    opts = confparse.Values()
    opts.argv = argv
    parsed = pattern.flat() + collected
    opts.cmds, opts.flags, opts.args = get_optvalues(parsed, meta)
    if defaults:
        for k, v in defaults(opts).items():
            if not hasattr(opts.flags, k) or not getattr(opts.flags, k):
                setattr(opts.flags, k, v)
    return opts

def get_optvalues(opts, handlers={}):

    """
    Given docopt dict, return 1). an optparse-like values object
    and (iow. with all short -o and long --opt)
    2). something similar for all <arguments>.
    """

    cmds = []
    flags, args = {}, {}
    for opt in opts:
        k = opt.name
        v = opt.value
        h = opt.meta if hasattr(opt, 'meta') and opt.meta else None
        if k[0]+k[-1] == '<>':
            k = k.strip('<>').replace('-', '_')
            d = args
        elif k.startswith('-'):
            k = k.lstrip('-').replace('-', '_')
            d = flags
        elif k.isupper():
            d = args
        else:
            if v:
                cmds.append(k)
            continue
        if isinstance(v, str) and v and '=' in v[0]:
            # allo access to subkey, value container for certain key
            d[k] = confparse.Values({ })
            for a in v:
                p, d = a.split('=')
                flags[k][p] = d
        else:
            if v:
                if h and h in handlers:
                    v = handlers[h](v)
            d[k] = v
    return cmds, confparse.Values(flags), confparse.Values(args)


select_kwdargs_defaults = dict(
    kwdarg_aliases={'g':'settings'}
)
def select_kwdargs(handler, settings, **override):

    """
    Given a function and a dictionary, return arguments and keywords
    for function with values from dictionary.
    """

    # get func signature
    func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
            inspect.getargspec(handler)
    # TODO: see about supporting part of this using better settings
    assert not func_args_var, "Arg. passthrough not supported"
    assert not func_kwds_var, "Kwds. passthrough not supported"
    # Make 'settings' accessible as a whole
    override['settings'] = settings
    # Resolve aliases before resolving argument values
    for i, a in enumerate(func_arg_vars):
        if a in settings.kwdarg_aliases:
            func_arg_vars[i] = settings.kwdarg_aliases[a]
    # Set values for positional arguments
    if not func_arg_vars:
        func_arg_vars = []
    for i, a in enumerate(func_arg_vars):
        if a in override:
            func_arg_vars[i] = override[a]
        elif a in settings:
            v = settings[a]
            func_arg_vars[i] = v
        else:
            func_arg_vars[i] = None
    # Set values for keywords arguments
    #if not func_defaults:
    func_defaults = {} # XXX: should be tuple of value items
    #for v in func_defaults:#.items():
    #    if k in settings.kwdarg_aliases:
    #        k = settings.kwdarg_aliases[k]
    #    if k in override:
    #        func_defaults[k] = override[k]
    #    elif k in settings:
    #        func_defaults[k] = settings[k]
    return func_arg_vars, func_defaults


def get_cmd_handlers_2(scope, prefix='cmd_'):
    """
    Translate each local function name to a key, return
    dictionary mapping with each function.
    """

    return dict([ ( n[len(prefix):].replace('_', '-'), scope[n] )
            for n in scope
            if n.startswith(prefix) ])


def get_cmd_handlers(scope, prefix='cmd_'):
    """
    Translate name for each function found in scope to keyname,
    but split at '_' (ie. '-' in the key) to created subgroups of commands.

    Two-levels only.
    """

    n = None
    cmdids = [ ( n[len(prefix):].split('_'), scope[n] )
            for n in scope
            if n.startswith(prefix) ]
    commands = {}
    for path, handler in cmdids:
        _commands = commands
        while path:
            p = path.pop(0)
            if path:
                if p not in _commands:
                    _commands[p] = {}
                _commands = _commands[p]
        _commands[p] = handler
    return commands


def run_commands(commands, settings, opts):

    """
    Take a nested dictionary with command names/handlers.
    Run the first and most specific one that matches names in opts.

    Uses select_kwdargs to resolve function arguments from settings and opts.
    Note select_kwdargs_defaults defines 'g' as an alias for settings,

    """

    cmds = opts.cmds
    if 'default' in opts:
        if cmds:
            d = len(cmds)
            default = [] if opts.default[:d] != cmds[:d] else opts.default[d:]
            if default:
                cmds.extend(default)
        else:
            if isinstance(opts.default, (list, tuple)):
                cmds = list(opts.default)
            else:
                cmds = [opts.default]

    while cmds:
        cmdid = cmds.pop(0)
        #assert cmdid in opts, \
        #        "Invalid docopts: command %r not described" % (cmdid)
        cmd = commands[cmdid]
        if isinstance(cmd, dict):
            subcmdid = cmdid = cmds.pop(0) if cmds else opts.default.pop(0)
            #assert subcmdid in opts, \
            #        "Invalid docopts: subcommand %r not described (for command %r)" % (
            #                subcmdid, cmdid)
            f = cmd[subcmdid]
            args, kwds = select_kwdargs(f, settings, opts=opts, **opts.args)
            ret = f(*args, **kwds)
            return ret_(ret) # non-zero exit
        else:
            args, kwds = select_kwdargs(cmd, settings, opts=opts, **opts.args)
            ret = cmd(*args, **kwds)
            return ret_(ret) # non-zero exit


def ret_(ret):
    if isinstance(ret, bool):
        if ret: return 0
        else: return 1
    else:
        return ret # non-zero exit


def cmd_help(CMD):
    """
    Print usage help for options and commands.
    """
    cmds = sys.modules['__main__'].commands
    print(sys.modules['__main__'].__usage__.strip())
    print("\nUsage:\n  hier.py help [ %s ]" % " | ".join(cmds.keys()))
    print()
    # Unknown Command prints only usage
    if CMD and CMD not in cmds:
        print("Use 'help' for a full usage listing with commands")
    else:
        for c, cmd in cmds.items():
            if CMD and c != CMD:
                continue
            if isinstance(cmd, dict):
                print(log.format_str("{blue}%s{default}" % c))
                for sc, scmd in cmd.items():
                    print(log.format_str("  {bblue}%s{default}" % (sc)))
                    doc = scmd.__doc__ and ' '.join(map(str.strip,
                            scmd.__doc__.split('\n'))) or '..'
                    print(log.format_str("    {bwhite}%s{default}" % doc))
            else:
                print(log.format_str("{bblue}%s{default}" % c))
                doc = cmd.__doc__ and ' '.join(map(str.strip,
                        cmd.__doc__.split('\n'))) or '..'
                print(log.format_str("    {bwhite}%s{default}" % doc))


def cmd_memdebug(settings):
    """
    Print info on resource usage, values in bytes.
    """
    # peak memory usage (bytes on OS X, kilobytes on Linux)
    res_usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    if os.uname()[0] == 'Linux':
        res_usage /= 1024; # kilobytes?
    # XXX: http://stackoverflow.com/questions/938733/total-memory-used-by-python-process
    #res_usage /= resource.getpagesize()

    if 'dbref' in settings:
        db_size = os.path.getsize(os.path.realpath(settings.dbref[10:]))
        for l, v in (
                ( 'Storage Size', lib.human_readable_bytefloat( db_size ) ),
        ):
            log.std('{green}%s{default}: {bwhite}%s{default} bytes', l, v)
    for l, v in (
            ( 'Resource Usage', lib.human_readable_bytefloat(res_usage) ),
        ):
            log.std('{green}%s{default}: {bwhite}%s{default} bytes', l, v)


def init_config(path, defaults={}, overrides={}, persist=[]):

    """
    Get settings from path. Use defaults to seed non-existant keys.
    Overwrite using overrides. Persists allows to indicate which settings
    are persisted.
    Any override key not in this list will be listed as volatile.
    Normally persist equals defaults.keys.
    """

    settings = confparse.load_path(path)
    if not persist:
        persist = defaults.keys()
    # FIXME: volatile/config_file handling should be in confparse
    if 'volatile' not in settings:
        defaults['volatile'] = ['config_file']
    for k, v in defaults.items():
        if k not in settings:
            setattr(settings, k, v)
    for k, v in overrides.items():
        if k not in persist:
            settings.volatile.append(k)
        setattr(settings, k, v)
    return settings

# XXX: static_vars_from_env is little use with docopt as it does not process
# flags/values unless needed for parsing. Might as well override static itself.

def static_vars_from_env(usage, *specs):
    for envname, default in specs:
        value = os.getenv(envname, default)
        if value is not default:
            usage = usage.replace( default, value )
    return usage

command_handlers = dict(
    help = cmd_help,
    memdebug = cmd_memdebug
)
