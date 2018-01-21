#!/usr/bin/env python
"""account -
:created: 2017-11-25
"""
from __future__ import print_function

__version__ = '0.0.4-dev' # script-mpe
__ledger_db__ = '~/.taxus-ledger.sqlite'
__usage__ = """

Usage:
  account.py [options] ( list )
  account.py [options] ( add | update ) <number> [ <id> ] [ <name> ]
  account.py [options] ( init | reset | stats )
  account.py [options] balance
  account.py [options] delete <spec>
  account.py [options] organize <spec>
  account.py [options] ( import | export | sumcsv ) <file-spec>
  account.py -h|--help|help
  account.py --version

Options:
    -I FMT, --input-format FMT
                  [default: rabocsv]
    -O FMT, --output-format FMT
                  [default: ledger]
    --start-balance=SPEC
    --end-balance=SPEC
                  Pass correction for account, format is '<SPEC>:<AMOUNT>'
    --start-date=DATA
    --end-date=DATE
                  ..
    --drop-all
                  Delete all tables on DB reset, on before DB init. This is off
                  by default to coexist with other schemas.
    -d REF, --dbref=REF
                  SQLAlchemy DB URL [default: %s]
    --no-db       ..
    -y, --yes     ..
    -s, --strict  ..
    -q, --quiet   Quiet operations
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).

""" % ( __ledger_db__, __version__ )
__doc__ += __usage__

import csv
import datetime
from UserDict import UserDict
from sqlalchemy import MetaData

from script_mpe.libhtd import *
from script_mpe.taxus import ledger as model




### Helper objects, one extending Taxus helper

class Ledger(UserDict):
    def write(self):
        pass

class Ledgers(Taxus):
    readers = dict(
        rabocsv=rabomut.csvreader,
    )
    writers = dict(
        ledger=ledger.writer
    )

    def fileformat(self, filename):
        if filename.endswith('.csv'):
            return 'rabocsv'
        elif filename.endswith('.xml'):
            return 'gnucash'
        elif filename.endswith('.dat'):
            return 'ledger'

    def assertaccount(self, accnr, _id=None, name=None, exists=False):
        a = self.Account.for_nr(self.sa_session, accnr, assert_exists=exists)
        if not a:
            if not name: name = str(accnr)
            d = dict(
                account_number=accnr, account_id=_id, name=name
            )
            a = self.Account().seed(**d)
            self.sa_session.add(a)
        return a

    def set_io_formats(self, in_spec, out_spec, g):
        # Scan filename if format is not user-set
        if g.default_input_format and in_spec:
            if_ = self.fileformat(in_spec)
            if if_: g.input_format = if_
        if g.default_output_format and out_spec:
            of = self.fileformat(out_spec)
            if of: g.output_format = of

    def load_ledger(self, file_spec, g):
        self.set_io_formats(file_spec, '.dat', g)

        reader = self.readers[ g.input_format ]
        # XXX: CSV reader tooling
        mutations = Ledger()
        fm = reader.fieldmap(None)
        m = reader.attrmap(fm)

        for m_ in reader(file_spec, reader.fields, mutations):

            fm.set_adaptee(m_)
            m.set_adaptee(fm)

            if not g.no_db:
                mutation = self.Mutation.forge(m, self, g)

                self.sa_session.add(mutation.from_account)
                self.sa_session.add(mutation.to_account)
                ctx.sa_session.commit()

                self.sa_session.add(mutation)

            if not g.quiet:
                self.writers[ g.output_format ](m)

        return mutations


### A few more globals

ctx = Ledgers(version='script_mpe.taxus.ledger')

cmd_default_settings = dict(
        quiet=False,
        database_tables=False,
        default_input_format=False,
        default_output_format=False )


### CLI Subcommands

def cmd_stats(g, opts):
    """
    Print table record stats.
    """
    global ctx
    sa = ctx.sa_session

    if g.database_tables:
        if g.database_tables:
            ctx.reflect()
            log.info("{yellow}Loaded tables from DB{default}")
        for t in ctx.metadata.tables:
            try:
                log.std("{blue}%s{default}: {bwhite}%s{default}",
                        t, sa.query(ctx.metadata.tables[t].count().alias("cnt")).all()[0][0])
            except Exception as e:
                log.err("Count failed for %s: %s", t, e)
        log.std("%i tables, done.", len(ctx.metadata.tables))

    else:
        for m in model.models:
            try:
                log.std("{blue}%s{default}: {bwhite}%s{default}",
                        m.__name__, sa.query(m).count())
            except Exception as e:
                log.err("Count failed for %s: %s", m, e)
        log.std("%i models, done.", len(model.models))

def cmd_init(g):
    global ctx
    ctx.create(drop_all=g.drop_all)
    log.std("%i tables, done.", len(ctx.metadata.tables))

def cmd_reset(g):
    global ctx
    ctx.reset()
    log.std("%i tables, done.", len(ctx.metadata.tables))

def cmd_list(g):
    global ctx
    # TODO: further parameterize ctx ws = Workdir.fetch()
    accs = ctx.Account.all()
    if g.strict and not accs:
        return 1
    for a in accs:
        print(a)

def cmd_balance(g):
    global ctx
    ctx.sa_session.query(ctx.Mutation).filter()

def cmd_add(number, id, name, g):
    global ctx
    ctx.assertaccount(number, _id=id, name=name, exists=False)
    ctx.sa_session.commit()

def cmd_update(number, id, name, g):
    global ctx
    ctx.assertaccount(number, _id=id, name=name)
    ctx.sa_session.commit()

def cmd_delete(SPEC, g):
    log.stderr("TODO export")
    return -1
def cmd_organize(g):
    log.stderr("TODO export")
    return -1

def cmd_categorise(g):
    """
    Find mutations with destination account for which no record exists.
    """
    log.stderr("TODO export")
    return -1

def cmd_import(file_spec, g):
    global ctx
    l = ctx.load_ledger(file_spec, g)
    ctx.sa_session.commit()

def cmd_export(g):
    global ctx
    ctx.writers[ g.output_format ]
    log.stderr("TODO export")
    return -1

def cmd_sumcsv(file_spec, g):
    global ctx
    l = Ledger()
    # XXX: l = ctx.load_ledger(file_spec, g)
    r = ctx.readers['rabocsv']
    f = [ 'date', 'cat', 'destacc', 'amount', 'line']
    line = 0
    debet, credit = 0, 0
    for date, cat, destacc, amount, line in r(file_spec, f, l):
        print(date, cat, destacc, amount)
        if amount > 0.0:
            credit += amount
        elif amount < 0.0:
            debet += amount
    print('Read', file_spec, line, 'lines', debet, credit)


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands['help'] = libcmd_docopt.cmd_help


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings, ctx
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    ctx.settings.update(opts.flags)
    opts.flags.update(ctx.settings)
    opts.flags.update(
        default_input_format = not (
                '-I' in opts.argv or '--intput-format' in opts.argv ),
        default_output_format = not (
                '-O' in opts.argv or '--output-format' in opts.argv ),
        dbref = ScriptMixin.assert_dbref(opts.flags['dbref'])
    )
    return init

def main(opts):

    """
    Execute command.
    """
    global ctx, commands

    # Can safely replace ctx.settings too since defaults() has integrated it
    ctx.settings = settings = opts.flags

    if not settings.no_db:
        assert settings.dbref
        ctx.session = 'default'
        ctx.setmetadata(None)
        ctx.init(settings.dbref)

    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    global __version__
    return '%s' % __version__


if __name__ == '__main__':
    import sys
    argv = sys.argv[1:]
    if not argv: argv = [ 'list' ]
    opts = libcmd_docopt.get_opts(__doc__, version=get_version(), argv=argv,
            defaults=defaults)
    sys.exit(main(opts))
