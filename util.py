import inspect

import confparse



def get_opt(opts):

    """
    Given docopt dict, return optparse-like values object.
    """

    r = {}
    for k, v in opts.items():
        if not k.startswith('-'):
            continue
        k = k.strip('-').replace('-', '_')
        # special case for properties
        if isinstance(v, basestring) and '=' in v[0]:
            r[k] = confparse.Values({ })
            for a in v:
                p, d = a.split('=')
                r[k][p] = d
        else:
            r[k] = v
    return confparse.Values(r)


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
    Run commands given at opts.

    FIXME: the depth or level of commands in docopt is lost, 
        therefore all commands including subcommands need unique names..
    """

    cmds = commands.keys()
    while cmds:
        cmdid = cmds.pop()
        assert cmdid in opts, \
                "Invalid docopts: command %r not described" % (cmdid)
        if not opts[cmdid]:
            continue
        cmd = commands[cmdid]
        if isinstance(cmd, dict):
            for subcmdid in cmd.keys():
                assert subcmdid in opts, \
                        "Invalid docopts: subcommand %r not described (for command %r)" % (subcmdid, cmdid)
                if not opts[subcmdid]:
                    continue
                f = cmd[subcmdid]
                args, kwds = select_kwdargs(f, settings, opts=opts)
                ret = f(*args, **kwds)
                if ret: return ret # non-zero exit
        else:
            args, kwds = select_kwdargs(cmd, settings, opts=opts)
            ret = cmd(*args, **kwds)
            if ret: return ret # non-zero exit
            print 'No result', cmds

