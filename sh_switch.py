#!/usr/bin/env python
"""
sh-switch
=========
Parse switch statements from Sh scripts.

:Created: 2016-06-16
:Updated: 2017-01-14


"""
__version__ = '0.0.3-dev' # script-mpe
__usage__ = """
sh-switch - Parse switch statements from Sh scripts

Usage:
    sh-switch [options] dump
    sh-switch [options] test-examples
    sh-switch [-V|--version|version]

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -p, --pretty  Pretty output formatting.
  -I <format>, --input-format <format>
                Override input format. See Formats_.
                TODO: default is to autodetect from filename
                if given, or set to [default: json].
  -O <format>, --output-format <format>
                Override output format. See Formats_.
                TODO: default is to autodetect from filename
                if given, or set to [default: json].
  --output-prefix PREFIX
                Path prefix for output [default: ]
  -V, --version
                Print version
"""
import re
import shlex

from docopt import docopt

import util, confparse, jsotk_lib



re_ws = re.compile('^\s+$')
re_nl = re.compile('[\r\n]')


class ShSwitch:

    def __init__(self):
        self.test_expr = None
        self.case_exprs = None
        self.line_from, self.line_to = None, None
        self.offset_from, self.offset_to = None, None



class SwitchReader:

    def __init__(self, filename ):

        self.filename = filename
        self.shf = open( filename )
        self.lexer = shlex.shlex( self.shf )
        self.lexer.whitespace = ''
        self.lexer.commenters = ''
        # Start parsing
        self.tokens = iter(self.lexer)
        # track line just to check we got all tokens correctly
        self.line = 0
        # current stack/buffers
        self.cases_stack = []
        self.comment = ''
        self.case_expr = ''
        self.case_close = ''
        # buffer line-leading whitespace before current token
        self.indent = ''
        # track offset before current token
        self.offset = 0

    def read_switches(self):

        """
        Create lexer and yield case/esac offsets as they are closed.
        Yields (<startchar>, <startline>), (<endchar>, <endline>) for each.
        """

        new_indent = None

        while self.tokens:
            token = self.tokens.next()

            nls = re_nl.subn('', token)[1]
            new_offset = self.shf.tell()

            if token == '#':
                self.comment += token

            if re_ws.match(token):
                if re_nl.match(token):
                    if self.comment: self.comment = ''
                    new_indent = ''

                elif not isinstance(self.indent, type(None)):
                    new_indent = self.indent + re_nl.sub('', token)

            elif self.comment:
                self.comment += token

            else:
                new_indent = None

            if token == 'case':
                self.cases_stack.append((self.offset, self.lexer.lineno,
                    self.indent, ShSwitch() ))
                assert self.switch
                assert isinstance( self.switch.test_expr, type(None))
                assert isinstance( self.switch.case_exprs, type(None) )

            elif token == 'esac':

                yield self.cases_stack.pop(), (new_offset, self.lexer.lineno)

            elif self.switch:

                if isinstance(self.switch.test_expr, type(None)):
                    self.switch.test_expr = ''

                if isinstance(self.switch.case_exprs, type(None)):
                    if token == 'in':
                        self.switch.case_exprs = {}
                        self.case_expr = ''
                    else:
                        self.switch.test_expr += token
                else:
                    if token == ';':
                        self.case_close += token
                        if self.case_close == ';;':
                            self.case_close = ''
                            self.case_expr = ''
                    elif re_ws.match(token):
                        self.case_close = ''

                    if token == ')':
                        self.switch.case_exprs[self.case_expr] = ''
                    elif self.case_expr in self.switch.case_exprs:
                        self.switch.case_exprs[self.case_expr] += token
                    else:
                        self.case_expr += token

            self.line += nls
            self.offset = new_offset
            self.indent = new_indent

    @property
    def switch(self):
        if self.cases_stack:
            return self.cases_stack[-1][-1]

    def get_offsets(self):
        "Yield ( <startchar>, <startline> )  ( <endchar>, <endline> ) "
        for start, end in self.read_switches():
            yield start[0:2], end[0:2]
            #print 'Switch', start[0:2], end[0:2]

    def get_all_sets(self):
        """Build nested dicts, with test expressions at the uneven levels
        and possible match groups at the even levels. """
        sets = self.get_raw_sets()
        return sets

    def get_raw_sets(self):
        """
        Return dicts mapping test-match expressions.
        Raw expressions only stripped of ' \n;'.
        """
        sets = []
        for start, end in self.read_switches():
            switch_expr = start[-1].test_expr.strip(' \n;')
            it = [
                k.strip(' \n;') for k in start[-1].case_exprs.keys()
            ]
            sets.append( dict([ (switch_expr, it) ]) )
        return sets

    def read_all(self):

        shsrc = open( self.filename ).read()
        for start, end in self.read_switches():
            switch_expr = start[-1].test_expr.strip(' \n;')
            it = [
                (k.strip(' \n;'), v.strip(' \n;')) for k, v in start[-1].case_exprs.items()
            ]
            #case_expr_map = dict(it)
            sets.append( dict([ (switch_expr, it) ]) )


# Command utils


# Subcommand handlers

def H_dump(ctx):
    for sh_fn in ctx.opts.args:
        reader = SwitchReader( sh_fn )
        jsotk_lib.stdout_data( reader.get_raw_sets(), ctx )


def H_test_examples(ctx):
    ctx.opts.args = [
        'tools/ci/build.sh',
        'test/var/sh-src-1.sh',
        'test/var/sh-src-3.sh'
    ]
    H_dump(ctx)

    #print list(reader.get_offsets())
    #reader.get_keys_at_levels()
    #reader.read_all()

def H_version(ctx):
    print 'script-mpe/'+__version__



### Main


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h


def main(ctx):

    ctx['in'] = ctx['inp']

    if ctx.opts.flags.version:
        ctx.opts.cmds = ['version']

    if not ctx.opts.cmds:
        ctx.opts.cmds = ['dump']

    return handlers[ ctx.opts.cmds[0] ](ctx)


if __name__ == '__main__':
    import sys, os
    ctx = confparse.Values(dict(
        usage=__usage__,
        path_exists=os.path.exists,
        sep=confparse.Values(dict(
            line=os.linesep
        )),
        out=sys.stdout,
        inp=sys.stdin,
        err=sys.stderr,
        opts=util.get_opts(__usage__)
    ))
    try:
        sys.exit( main( ctx ) )
    except Exception as err:
        if not ctx.opts.flags.quiet:
            import traceback
            tb = traceback.format_exc()
            print(tb)
            print('Unexpected Error:', err)
        sys.exit(1)

