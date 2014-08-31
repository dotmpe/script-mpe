import sys
import inspect

from docopt import docopt

import confparse
import log



def get_opts(docstr, version=None, argv=None):
    """
    Get docopt dict, and set argv and flags from get_optvalues.
    """
    if not argv:
        argv = sys.argv[1:]
    opts = docopt(docstr, argv, version=version)
    assert not ( 'argv' in opts or 'flags' in opts or 'args' in opts),\
            "Dont use 'argv', 'flags' or 'args'. "
    opts.argv = argv
    opts.flags, opts.args = get_optvalues(opts)
    return opts

def get_optvalues(opts):

    """
    Given docopt dict, return 1). an optparse-like values object 
    and (iow. with all short -o and long --opt) 
    2). something similar for all <arguments>.
    """

    flags, args = {}, {}
    for k, v in opts.items():
        if k[0]+k[-1] == '<>':
            k = k.strip('<>').replace('-', '_')
            d = args
        elif k.startswith('-'):
            k = k.lstrip('-').replace('-', '_')
            d = flags
        else:
            continue
        if isinstance(v, basestring) and '=' in v[0]:
            d[k] = confparse.Values({ })
            for a in v:
                p, d = a.split('=')
                flags[k][p] = d
        else:
            d[k] = v
    return confparse.Values(flags), confparse.Values(args)


def select_kwdargs(handler, settings, **override):

    """
    Given a function and a dictionary, return arguments and keywords 
    for function with values from dictionary.
    """

    # get func signature
    func_arg_vars, func_args_var, func_kwds_var, func_defaults = \
            inspect.getargspec(handler)
    assert not func_args_var, "Arg. passthrough not supported"
    assert not func_kwds_var, "Kwds. passthrough not supported"
    # Make 'settings' accessible as a whole
    override['settings'] = settings
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
    if not func_defaults:
        func_defaults = {}
    for k, v in func_defaults.items():
        if k in override:
            func_defaults[k] = override[k]
        elif k in settings:
            func_defaults[k] = settings[k]
    return func_arg_vars, func_defaults


def get_cmd_handlers(scope, prefix='cmd_'):

    """
    Assemble nested dictionary containing functions.
    Functions with prefix from scope are split at '_' and
    embedded. Two-levels only.
    """

    n = None
    cmdids = [ ( n[4:].split('_'), scope[n] )
            for n in scope
            if n.startswith('cmd_') ]
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

    Uses select_kwdargs to determine function arguments from settings and opts.
    """

    cmds = {}
    # get arg sequence from docopt dict
    for opt in opts:
        if opt.startswith('-') or opt[0]+opt[-1] == '<>':
            continue
        if opts[opt]:
            i = opts.argv.index(opt)
            cmds[i] = opt

    cmds = cmds.values()

    while cmds:
        cmdid = cmds.pop(0)
        assert cmdid in opts, \
                "Invalid docopts: command %r not described" % (cmdid)
        cmd = commands[cmdid]
        if isinstance(cmd, dict):
            subcmdid = cmds.pop(0)
            assert subcmdid in opts, \
                    "Invalid docopts: subcommand %r not described (for command %r)" % (subcmdid, cmdid)
            f = cmd[subcmdid]
            args, kwds = select_kwdargs(f, settings, opts=opts)
            ret = f(*args, **kwds)
            if ret: return ret # non-zero exit
        else:
            args, kwds = select_kwdargs(cmd, settings, opts=opts)
            ret = cmd(*args, **kwds)
            if ret: return ret # non-zero exit


def cmd_help():
    cmds = sys.modules['__main__'].commands
    for c, cmd in cmds.items():
        if isinstance(cmd, dict):
            print log.format_line("{blue}%s{default}" % c)
            for sc, scmd in cmd.items():
                print log.format_line("  {bblue}%s{default}" % (sc))
                doc = scmd.__doc__ and ' '.join(map(str.strip,
                        scmd.__doc__.split('\n'))) or '..'
                print log.format_line("    {bwhite}%s{default}" % doc)
        else:
            print log.format_line("{bblue}%s{default}" % c)
            doc = cmd.__doc__ and ' '.join(map(str.strip,
                    cmd.__doc__.split('\n'))) or '..'
            print log.format_line("    {bwhite}%s{default}" % doc)




