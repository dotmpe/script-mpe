#!/usr/bin/env python
"""
sh-execnames
============
Get executable names used in Sh script
"""
from __future__ import print_function
__usage__ = """
sh-execnames - Get executable names used in Sh script

TODO: partial sh-script parser to merge with other sh_*py
    - parse stdio redirs
    - remove/ignore inline env in front
    - report on all commands used in script
    - not parsing functions, cant tell executables from alias or function.
      Filter out builtins by option w/ default.

Usage:
    sh-execnames [options] dump <src>...
    sh-execnames [options] [--exec] [--vars] names <src>...
    sh-execnames [-h|--help|help]

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  --output-format SPEC
                Values: plain, offset, or provide format directly.
                [default: offset]
  --ignore BUILTIN
                Ignore these names
                [default: ]

test,true,false,echo,if,then,else,fi,while,do,done,case,esac,shift,return,continue
"""
import re
import shlex

from docopt import docopt

from script_mpe import libcmd_docopt, confparse, jsotk_lib


re_ws = re.compile('^\s+$')
re_nl = re.compile('[\r\n]')
re_cmd = re.compile('[A-Za-z_][A-Za-z0-9\._-]+')

class OutputFormat:
    PLAIN = '%(execname)s'
    OFFSET = '%(lineno)i %(charoffset)s %(execname)s'

class ShellScriptParserContext:

    def __init__(self, ignore, format=OutputFormat.OFFSET, tokens=None):
        self.ignore = ignore
        self.format = format
        self.comment = ''
        self.indent = ''
        self.new_indent = ''
        self.buffer = ''
        self.stack = []
        self.pipeline = []
        self.cmd = []
        self.new_indent = None
        self.io_expr = []
        self.tokens = tokens

    def add(self, token):
        if token == '#':
            self.comment += token

        elif re_ws.match(token):

            if re_nl.match(token):
                self.end_line()

            else:
                if not cmd:
                    self.indent += token
                    #re_nl.sub('', token)

        else:
            if self.comment:
                self.comment += token

            else:
                self.buffer += token

        if self.buffer == '$(':
            self.cmd = []
        elif token == ')':
            pass


    def end_line():
        if self.comment: self.comment = ''
        self.new_indent = ''


class ShellScriptParser:

    def __init__(self, filename):
        self.filename = filename
        self.shf = open( filename )
        self.lexer = shlex.shlex( self.shf )
        self.lexer.whitespace = ''
        self.lexer.commenters = ''
        self.lexer.wordchars = 'abcdfeghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._'
        #self.lexer.whitespace_split = True

    def print(self, name):
        if name in self.ignore:
            return
        print(self.format % {
            'lineno': self.tokens.lineno,
            'charoffset': self.tokens.instream.tell(),
            'execname': name })

    def read(self, ignore, format):

        # Start parsing
        self.tokens = tokens = iter(self.lexer)
        self.context = ShellScriptParser(ignore, format, self.tokens)

        # single level command/pipeline
        for token in tokens:
            self.add(token)

            #print(tokens.lineno, token, type(token))

            if token == '(':
                #print(tokens.lineno, token, cmd, cmds)
                self.print(cmd[0])
                cmds.append(cmd)
                cmd = []

            if token == ')':
                if not cmd:
                    cmd = cmds[-1]
                if cmd:
                    if cmd[-1] == '(':
                        func = cmds[-1]
                        #print('func', func)
                        cmds.pop()
                        cmd = []
                    elif cmd[0] == '(':
                        cmd = cmd[1:]
                if cmd:
                    if re_cmd.match(cmd[0]):
                        self.print(cmd[0])
                cmd = []
                io_expr = []
                #assert cmd, (tokens.lineno, token)

            elif token in '|':
                if not cmd:
                    # parse as || /or
                    assert cmds, (tokens.lineno, token, cmd, cmds)
                    if pipeline:
                        cmd = pipeline.pop()
                        self.print(cmd[0])
                    else:
                        cmd = []
                    pass
                else:
                    assert cmd, (tokens.lineno, token)
                    pipeline.append(cmd)
                cmd = []

            elif token == '>':
                io_expr = [token]

            elif token in '{};':
                if pipeline:
                    if cmd:
                        pipeline.append(cmd)
                        if re_cmd.match(cmd[0]):
                            self.print(cmd[0])
                    pass # print(pipeline)
                elif cmd:
                    pass # print(cmd)
                    if re_cmd.match(cmd[0]):
                        self.print(cmd[0])
                pipeline = []
                cmd = []
                io_expr = []

            elif io_expr:
                io_expr.append(token)

            elif token in ( 'do', 'then' ):
                cmds.append(cmd)
                cmd = []

            elif token in ( 'done', 'fi' ):
                if cmd:
                    if re_cmd.match(cmd[0]):
                        self.print(cmd[0])
                cmd = cmds.pop()

            else:
                cmd.append(token)

            # print(tokens.lineno, token, type(token))


# Subcommand handlers

def H_names(ctx):
    """
    scan for name of executables or references to variables
    XXX: shlex does not help much tokenizing shell script
    """
    for sh_fn in ctx.opts.args.src:
        lexer = shlex.shlex( open(sh_fn).read() )
        for t in lexer:
            if re_cmd.match(t):
                print(t)
                if is_exec(t):
                    print(t)

def is_exec(name):
    try:
        lib.cmd("which "+name)
    except:
        return False
    return True

re_cmd = re.compile('^[A-Za-z_][A-Za-z0-9\._-]*$')

def H_dump(ctx):
    output_format = ctx.opts.flags.output_format.upper()
    if hasattr(OutputFormat, output_format):
        output_format = getattr(OutputFormat, output_format)

    for sh_fn in ctx.opts.args.src:
        #ssp = ShellScriptParser(sh_fn)
        #ssp.read(ctx.opts.flags.ignore.split(','), output_format)

        lexer = shlex.shlex( open(sh_fn).read() )
        # Start parsing
        for t in lexer:
            print(t)


### Main


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h


def main(ctx):

    ctx['in'] = ctx['inp']

    if not ctx.opts.cmds:
        ctx.opts.cmds = ['dump']

    return handlers[ ctx.opts.cmds[0] ](ctx)

if __name__ == '__main__':
    import sys, os
    if sys.argv[-1] == 'help':
        sys.argv[-1] = '--help'
    ctx = confparse.Values(dict(
        usage=__usage__,
        path_exists=os.path.exists,
        sep=confparse.Values(dict(
            line=os.linesep
        )),
        out=sys.stdout,
        inp=sys.stdin,
        err=sys.stderr,
        opts=libcmd_docopt.get_opts(__usage__)
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
