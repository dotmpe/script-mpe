#!/usr/bin/env python
""":created: 2015-11-30
"""
from __future__ import print_function
__description__ = "twitter-meta - twitter document proc"
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Usage:
  twitter-meta.py [options] info
  twitter-meta.py [options] lists
  twitter-meta.py [options] verify-credentials
  twitter-meta.py [options] check-rate-limit URL
  twitter-meta.py [options] lists-create NAME [MODE] [DESCR]
  twitter-meta.py [options] lists-update NAME [MODE] [DESCR]
  twitter-meta.py [options] lists-destroy [LIST_ID|SLUG OWNER_ID]
  twitter-meta.py help
  twitter-meta.py -h|--help
  twitter-meta.py --version

Other flags:
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

    -q, --quiet   Alias..
    --short       Show only name/ID values.
    --field-separator CHAR
                  Field separator [default: \t]
    --fields      Display columns. Values depends per object [default: []].
    --cache-timeout SEC
                  [default: 60].

""" % ( __version__ )
import os
from pprint import pformat

import libcmd_docopt

import twitter



env_map = (
        ('consumer_secret', 'TWITTER_API_SECRET'),
        ('consumer_key', 'TWITTER_API_KEY'),
        ('access_token_secret', 'TWITTER_ACCESS_TOKEN_SECRET'),
        ('access_token_key', 'TWITTER_ACCESS_TOKEN_KEY')
    )

def get_keys_from_env():
    keys = {}
    for kw_key, env_key in env_map:
        keys[kw_key] = os.getenv(env_key)
    return keys

def print_tabline(o, opts):
    line = []
    for f in opts.flags.fields:
        line += [ str(getattr( o, f )) ]
    print(opts.flags.field_separator.join(line))

def set_default_args(opts, **kv):
    for k, v in kv.items():
        if not hasattr(opts.args, k) or not getattr(opts.args, k):
            setattr(opts.args, k, v)

def keystolower(**kv):
    ret = {}
    for k, v in kv.items():
        ret[k.lower()] = v
    return ret

def filternone(**kv):
    for k, v in kv.items():
        if v:
            yield k, v

def get_args(opts):
    return dict(filternone(**keystolower(**opts.args.todict())))



### Commands

def cmd_info(opts):
    """
    """
    print(commands.keys())
    #print pformat(opts.todict())
    for methodName in dir(opts.api):
        attr = getattr(opts.api, methodName)
        if methodName.startswith('_') or not callable(attr):
            continue
        print(methodName)

    #return cmd_verify_credentials(opts)


def cmd_verify_credentials(opts):
    """
    """
    print(opts.api.VerifyCredentials())


lists_fields = (
        'id', 'name', 'mode', 'member_count', 'subscriber_count',
# 'description', 'following', 'full_name', 'id', 'member_count', 'mode', 'name', 'param_defaults', 'slug', 'subscriber_count', 'uri', 'user'
        )

def cmd_lists(opts):
    limit = opts.api.CheckRateLimit('lists/list')
    if limit.remaining == 0:
        print("# Throttled")
        return 1
    if opts.flags.quiet:
        opts.flags.short = True
    if not opts.flags.fields:
        opts.flags.fields = lists_fields
    lists = opts.api.GetListsList()
    for ls in lists:
        if opts.flags.short:
            print(ls.full_name)
        else:
            print_tabline(ls, opts)

def cmd_lists_create(opts):
    limit = opts.api.CheckRateLimit('lists/create')
    if limit.remaining == 0:
        print("# Throttled")
        return 1
    set_default_args(opts, mode="private", description="")
    l = opts.api.CreateList(**get_args(opts))
    print(l)

def cmd_lists_destroy(opts):
    limit = opts.api.CheckRateLimit('lists/destroy')
    if limit.remaining == 0:
        print("# Throttled")
        return 1
    set_default_args(opts,
            LIST_ID=None,
            SLUG=None,
            OWNER_ID=None,
            OWNER_SCREEN_NAME=None,
        )
    if opts.args.SLUG:
        if opts.args.OWNER_ID.isdigit():
            opts.args.OWNER_ID = int(opts.args.OWNER_ID)
        else:
            opts.args.OWNER_SCREEN_NAME = opts.args.OWNER_ID
            opts.args.OWNER_ID = None

    elif opts.args.LIST_ID:
        opts.args.LIST_ID = int(opts.args.LIST_ID)

    l = opts.api.DestroyList(**get_args(opts))
    print(l)


# X-META-1: maybe revise x-meta and think about this
#def twitter_crud(set_name, obj_name, act_names):
#    def twitter_crud_inner(opts):
#        limit = opts.api.CheckRateLimit('%s/%s' % ( set_name, act_name))
#        if limit.remaining == 0:
#            print("# Throttled")
#            return 1
#        set_default_args(opts, **defs)
#        l = getattr(opts.api, act_name.title()+obj_name.title())(
#                **get_args(opts))
#        print(l)
#
#    func_name = "cmd_%s_%s" % (set_name, act_name)
#    twitter_crud_inner.__name__ = func_name
#    globals()[func_name] = twitter_crud_inner
#twitter_crud('lists', 'list', (
#        ( 'create', dict( mode="private", description="" ) ),
#        ( 'update', dict( mode="private", description="" ) ),
#        ( 'destroy', dict( ) )))



def cmd_check_rate_limit(opts):
    print(opts.api.CheckRateLimit(opts.args.url))


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    api_keys = get_keys_from_env()
    opts.api = twitter.Api(**api_keys)
    if opts.flags.cache_timeout != 60:
        opts.api.SetCacheTimeout(opts.flags.cache_timeout)

    return libcmd_docopt.run_commands(commands, opts.flags, opts)

def get_version():
    return 'twitter-meta.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__description__ + '\n' + __usage__, version=get_version())
    sys.exit(main(opts))
