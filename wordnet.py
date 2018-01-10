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
  wordnet.py [options] ( define | meanings | path | tree | positions | examples ) WORD
  wordnet.py info
  wordnet.py -h|--help
  wordnet.py help [ CMD ]
  wordnet.py --version

Options:
    --no-head
                  Don't include query as header line or indent results.
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
        Print short definition for word name or synonyms.
        Each definition has all lemmas, a lexical name and the word name.
    """
    return printcmd_word_meanings(WORD, g)


def cmd_define(WORD, g):
    """
        Print dictionary info for word name or synonyms.
    """

    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)
    if not syn and not syns:
        log.stderr('{yellow}No results{default}')
        return 1

    d, defs = 1, 0
    if syn:
        WORD, _, d = WORD.split('.')
        d = int(d)

    # XXX: maybe move word outside, together with short origin and
    # pronounciation as most including oldest dictionary typographies do
    for i, s in enumerate(syns):
        defs += 1
        if i != 0: print( "%s(%i)" % (WORD.upper(), defs), end='. ')
        else: print(WORD.upper(), end='. ')
        print_short_def(s, w=WORD)
        print((' '*INDENT*(1+d))+position_label(s)+' '+s.definition())
        if s.examples():
            print()
        for e in s.examples():
            print((' '*INDENT*(2+d))+'"%s"'%(e,))

        # TODO: how to get at derived forms?
        #for a in s.entailments() + s.similar_tos() + s.also_sees():
        #    print((' '*INDENT*(1+d))+', '.join(a.name()))

        if len(syns)>1: print()


def cmd_path(WORD, g):
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)
    if not syn and not syns:
        log.stderr('{yellow}No results{default}')
        return 1

    d_ = 0
    if g.head:
        if syn:
            WORD = wn_sense(WORD, syn)
        log.stdout('{green}'+WORD+'{blue}')
        d_ += 1
    for i, syn in enumerate(syns):
        print_short_def(syn, w=WORD, d=d_, i=i)
        for d, x in traverse_hypernyms(syn, d_+1):
            print_short_def(x, w=WORD, d=d)
            pass#print(x)


def cmd_tree(WORD, g):
    """
        Like list, but follow each definition by all hypernyms.
        Indents each generalization one further level.
    """
    return printcmd_word_trees(WORD, g)


def cmd_positions(WORD, g):
    """
        Print positions that given word name or synonym appears in speech:
        adj, adj-sat, adv, noun and/or verb.
    """
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)
    if not syn and not syns:
        log.stderr('{yellow}No results{default}')
        return 1

    for s in syns: poss = set( poss + position_label(s) )
    print(" ".join(poss))


def cmd_examples(WORD, g):
    """
        List soft definitions with examples for word name or synonyms. Skip
        synonyms without examples.
    """
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)
    if not syn and not syns:
        log.stderr('{yellow}No results{blue}')
        return 1

    d = 0
    if g.head:
        if syn:
            WORD = wn_sense(WORD, syn)
        log.stdout('{green}'+WORD+'{blue}')
        d = 1
    for i, s in enumerate(syns):
        if not s.examples(): continue
        print_short_def(s, d=d, i=i, w=WORD)
        print()
        for e in s.examples():
            if syn: i=None
            print((' '*INDENT*(1+d))+'"%s"'%(e,))

        if i+1<len(syns):
            print()


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
    opts.flags.update(dict(
        head = not opts.flags.no_head
    ))
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

    if os.getenv('TERM', None) == 'dumb':
        log.formatting_enabled = False

    opts = libcmd_docopt.get_opts(__description__+'\n'+__usage__,
            version=get_version(), defaults=defaults)
    sys.exit(main(opts))
