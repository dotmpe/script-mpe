#!/usr/bin/env python
""":Created: 2017-04-08
:Updated: 2023-08-08
"""
import os
__short_description__ = 'db.mpe - (Any)dbm index client'
__description__ = __doc__
__version__ = '0.0.4-dev+script.mpe' #script-mpe
__db__ = '~/.script.db'
__usage__ = """
Usage:
  db.py [options] insert <key> [<label>]
  db.py [options] exist <key>
  db.py [options] exists <keys>...
  db.py [options] drop <keys>...
  db.py [options] find <glob>
  db.py [options] get <key>
  db.py [options] set <kvs>...
  db.py [options] [list]
  db.py [options] dump
  db.py [options] about
  db.py (--background|bg|background) [options]

Options:
    -q, --quiet   XXX: Quiet operations
    -s, --strict  XXX: Strict operations
    -k, --key     XXX: Match (all) keys instead of tag labels.
    -S SEP, --field-separator SEP
                  Separate key from values by string SEP [default: \\t]
    -N END, --line-end END
                  End lines with string END [default: %s]
    --db DBREF    Database path [default: %s]
    --no-db       XXX: Set for some commands..
    --new         XXX: Truncate DB file
    --init        Create if DB file does not exist
    --read        Read-only DB file
    -h --help     Show this usage description.
    --version     Show version (%s).

""" % (
    os.linesep.encode('unicode-escape').decode('utf-8'),
    __db__, __version__ )
import dbm
# XXX: See also ``import shelve`` for pickled objects

from script_mpe import libcmd_docopt


def get_any_session(opts):
    "Get session for DB file reference"
    flag = opts.flags.read and 'r' or 'w'
    if opts.flags.init:
      assert flag == 'w' and not opts.flags.new, "Cannot create file in read-only mode"
      flag = 'c'
    elif opts.flags.new:
      flag = 'n'
    dbref = os.path.expanduser(opts.flags.db)
    return dbm.open(dbref, flag)



def H_about(ctx):
    print(ctx.description)

def H_exist(data, opts, key):
    return H_exists(data, opts, [key])

def H_exists(data, opts, keys):
    if len(keys) == 0:
      return 2
    for k in keys:
      if k not in data:
        return 3

def H_list(data, opts):
    """
    TODO: re-instate some anydbm tooling when needed. See
    git:b7fc8a7f:tags.py for tag handlers.
    """
    for k in data.keys():
      print(k.decode('ascii'))

def H_dump(data, opts, g):
    """
    Dump db key, values
    """
    for k in data.keys():
        print(k.decode('ascii')+g.field_separator+data[k].decode('utf-8'),
            end=g.line_end)

def H_drop(data, opts, keys):
  if len(keys) == 0:
    return 2
  for k in keys:
    del data[k]

def H_set(data, opts, kvs):
  if len(kvs) == 0:
    return 2
  while len(kvs) > 0:
    k, v = kvs[:2]
    data[k] = v
    kvs = kvs[2:]


### Transform H_ function names to nested dict

handlers = libcmd_docopt.get_cmd_handlers_2(globals(), 'H_')


### Main

def main(ctx):
    global handlers

    g = settings = libcmd_docopt.init_settings()
    db = get_any_session(ctx.opts)
    flags = ctx.opts.flags
    if not flags.no_db:
        assert db != None, "Missing DB: %s " % flags.db
    ctx.data = db

    ctx.field_separator = flags.field_separator\
        .encode('utf-8').decode('unicode-escape')
    ctx.line_end = flags.line_end\
        .encode('utf-8').decode('unicode-escape')

    return libcmd_docopt.run_commands(handlers, ctx, ctx.opts)


def get_version():
    return 'db.mpe/%s' % __version__

if __name__ == '__main__':
    import sys
    ctx = libcmd_docopt.init_for_module(sys.modules[__name__], {}, dict(
      kwdarg_aliases=dict(ctx='settings')))
    if len(ctx.opts.cmds) == 0: ctx.opts.cmds = ['list']
    sys.exit( main( ctx ))
