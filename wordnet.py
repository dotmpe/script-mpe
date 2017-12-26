#!/usr/bin/env python
"""
:created: 2017-12-26

Query Wordnet corpus with Python NLTK. Wordnet has hypernym, hyponym, antonym
synonym relations, derived forms, examples and more.

Retrieves synonym sets for words, or a specific sense given a synset name.

"""
from __future__ import print_function
__description__ = "wordnet - query Wordnet corpus with Python NLTK"
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Usage:
  wordnet.py [options] ( meanings | define | tree | positions | examples ) WORD
  wordnet.py info
  wordnet.py -h|--help
  wordnet.py help [ CMD ]
  wordnet.py --version

Options:
    --head
                  Include query as header line, indent results starting at
                  level 1.
    --print-memory
                  Print memory usage just before program ends.
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help'.
    --version     Show version (%s).
"""
import os
from pprint import pformat, pprint

import log
import libcmd_docopt
from libwn import *


cmd_default_settings = dict(
        verbose=1
    )


### Commands


def cmd_info(g):
    print(sorted(wn.langs()))

def cmd_meanings(WORD, g):
    """
        Define word, lists hyponyms found.
        Each line has all lemmas, the name and lexical name.
    """
    return printcmd_word_meanings(WORD, g)

def cmd_define(WORD, g):
    """
        Print dictionary info.
    """
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    d, defs = 1, 0
    if syn:
        WORD, _, defs = WORD.split('.')
        defs = int(defs)

    # XXX: maybe move word outside, together with short origin and
    # pronounciation as most including oldest dictionary typographies do
    for i, s in enumerate(syns):
        if not syn:
            print("%s(%i)" % (WORD.upper(), defs), end='. ')
        else:
            print(WORD.upper(), end='. ')
        print_short_def(s)
        print((' '*INDENT*(1+d))+position_label(s)+'. '+s.definition())
        if s.examples():
            print()
        for e in s.examples():
            print((' '*INDENT*(2+d))+'"%s"'%(e,))

        # TODO: how to get at derived forms?
        #for a in s.entailments() + s.similar_tos() + s.also_sees():
        #    print((' '*INDENT*(1+d))+', '.join(a.name()))

        defs += 1
        if not syn:
            print()

def cmd_tree(WORD, g):
    """
        Like list, but follow each definition by a all hypernym superordinates,
        indenting each generalization one more level.
    """
    return printcmd_word_trees(WORD, g)

def cmd_positions(WORD, g):
    """
        Print positions that word appears in speech:
        adj, adj-sat, adv, noun and/or verb.
    """
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    for s in syns:
        poss = set( poss + position_label(s) )
    print(" ".join(poss))

def cmd_examples(WORD, g):
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    d = 0
    if g.head:
        print(WORD)
        d = 1
    for i, s in enumerate(syns):
        for e in s.examples():
            if syn: i=None
            print_short_def(s, d=d, i=i)
            print((' '*INDENT*(1+d))+'"%s"'%(e,))


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands.update(dict(
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug
))


### Util functions to run above functions from cmdline

def defaults(opts, init={}):
    global cmd_default_settings
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    return init

def main(opts):

    """
    Execute command.
    """
    global ctx, commands

    settings = opts.flags

    ret = libcmd_docopt.run_commands(commands, settings, opts)
    if settings.print_memory:
        libcmd_docopt.cmd_memdebug(settings)
    return ret

def get_version():
    return 'wordnet.mpe/%s' % __version__


if __name__ == '__main__':
    import sys

    opts = libcmd_docopt.get_opts(__description__+'\n'+__usage__,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
