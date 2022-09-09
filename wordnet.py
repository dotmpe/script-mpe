#!/usr/bin/env python
"""
:created: 2017-12-26
:updated: 2022-08-10

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
  wordnet.py [options] info [ WORD [ LANG ] ]
  wordnet.py [options] lemmas WORD
  wordnet.py [options] ( list | definitions ) WORD
  wordnet.py [options] words [ LANG ]
  wordnet.py citation [ LANG ]
  wordnet.py readme [ LANG ]
  wordnet.py -h|--help
  wordnet.py help [ CMD ]
  wordnet.py docs
  wordnet.py --version

Options:
    --max-sublist NUM
                  Try to curb 'info' output a bit... [default: 10]
    --count
    --no-head
                  Don't include query as header line or indent results.
    --print-memory
                  Print memory usage just before program ends.
    -h --help     Show this usage description.
                  For a command and argument description use the command 'help',
                  or 'docs' to print the Python module documentation.
    --version     Show version (%s).
""" % __version__
import os
from pprint import pformat, pprint

import log
import libcmd_docopt

# Some utils for nltk.corpus to query WordNet dataset
import libwn
from libwn import *


cmd_default_settings = dict(
        verbose=1
    )


### Commands


def cmd_info(WORD, LANG, g):
    """
    Show license, version, word count.

    Without WORD or LANG list languages.
    Given a WORD list or count the definitions (Synsets).

    Given only LANG either count words or
    FIXME: how to switch language with wn.synset?
    """
    log.stderr('{green}Wordnet version{default}:')
    print(wn.get_version())
    if LANG:
        log.stderr("{green}License for '%s' data{default}:" % LANG)
        print(wn.license(LANG))

        if not WORD:
            iter_ = wn.words(LANG)
            items = list(iter_)
            log.stderr("{green}Wordnet for '%s' word count{default}:" % LANG)
            print(len(items))
            return

        else:
            log.stderr('{yellow}FIXME{default}')
            return 1

    else:
        log.stderr("{green}License for 'eng' data{default}:")
        print(wn.license())
        if not WORD:
            log.stderr('{green}Languages{default}:')
            print("\n".join(sorted(wn.langs())))
            return

    syn, syns = syn_or_syns(WORD)
    if syn:
        print('Synset:', syn.name(), '(Lemma %r, position %r)' % (
                syn.lemma_names()[0],
                syn.pos()
            ))
        for fn, ak, lt in synset_field_attr_map:
            v = getattr(syn, ak)(); it = None; it2 = None

            if lt == 1: # Synsets in list
                for it in u_o_ml(fn, v, g):
                    print('-', it.name())

            elif lt == 2: # Tuple with distance in second position
                for it in u_o_ml(fn, v, g):
                    print('-', '%i:' % it[1], it[0].name())

            elif lt == 3: # Sublist with Synsets
                for it in u_o_ml(fn, v, g):
                    print('-')
                    for it2 in it:
                        print(' ', '-', it2.name())

            elif lt == 4: # Primitive type (int, string) in list
                for it in u_o_ml(fn, v, g):
                    print('-', it)

            else:
                print('%s:' % fn, v)

        #print(dir(syn))
        # empty lists, identical to -to_?
        #print(syn.in_region_domains())
        #print(syn.in_topic_domains())
        #print(syn.in_usage_domains())
    else:
        print(len(syns))
        log.stderr('{green}%i definition(s) found for %r{default}' % (len(syns), WORD))


def cmd_citation(LANG, g):
    "Display citation.bit from language package"
    if not LANG: LANG = 'eng'
    log.stderr("{green}Citation for '%s' language{default}:" % LANG)
    print(wn.citation(LANG))


def cmd_define(WORD, g):
    """
        Print dictionary info for word name or synonyms.
    """
    ret, (syn, syns) = u_q_w(WORD, g)
    if ret: return ret

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


def cmd_definitions(WORD, g):
    """
        List just the 'sense terms', ie. the Synset names found for query WORD
    """
    ret, (syn, syns) = u_q_w(WORD, g)
    if ret: return ret
    #if syn: syns = [syn]
    for syn in syns:
        print(syn.name())


def cmd_docs(g):
    "Print pydocs"
    print("wordnet.py docs:"+__doc__ + """libwn.py docs: """ + libwn.__doc__)


def cmd_examples(WORD, g):
    """
        List soft definitions with examples for word name or synonyms. Skip
        synonyms without examples.
    """
    ret, (syn, syns) = u_q_w(WORD, g)
    if ret: return ret

    d = 0
    if g.head:
        if syn:
            WORD = wn_sense(WORD, syn)
        log.stdout('{green}'+WORD+'{default}')
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
    log.stdout('{default}')


def cmd_lemmas(WORD, g):
    """
    Query <lemmal>.<position>.<number>.<lemma>

    Retrieve and list Lemma-type objects.
    """
    lemmas = wn.lemmas(WORD)
    if len(lemmas):
        for it in u_o_ml('Lemmas for', lemmas, g):
            print("- '%s' <%s> %s" % (it.name(), it.key(), it.synset().name()))
    else:
        lemma = wn.lemma(WORD)
        if g.count:
            print(wn.lemma_count(lemma))
        else:
            print(lemma)


def cmd_meanings(WORD, g):
    """
        Pretty-print short definition for word name or synonyms.
        Each definition has all lemmas, a lexical name and the word name.
    """
    return printcmd_word_meanings(WORD, g)


def cmd_path(WORD, g):
    syn, syns = u_q_w(WORD, g)

    d_ = 0
    if g.head:
        if syn:
            WORD = wn_sense(WORD, syn)
        log.stdout('{green}'+WORD+'{default}')
        d_ += 1
    for i, syn in enumerate(syns):
        print_short_def(syn, w=WORD, d=d_, i=i)
        for d, x in traverse_hypernyms(syn, d_+1):
            print_short_def(x, w=WORD, d=d)
            pass#print(x)


def cmd_positions(WORD, g):
    """
        Print positions that given word name or synonym appears in speech:
        adj., adj.sat., adv., n. and/or v.
    """
    ret, (syn, syns) = u_q_w(WORD, g)
    if ret: return ret

    print(" ".join( set( [ position_label(s) for s in syns ] ) ))


def cmd_readme(LANG, g):
    "Display ReadMe file from language package"
    if not LANG: LANG = 'eng'
    log.stderr("{green}ReadMe for '%s' language{default}:" % LANG)
    print(wn.readme(LANG))


def cmd_tree(WORD, g):
    """
        Like list, but follow each definition by all hypernyms.
        Indents each generalization one further level.
    """
    return printcmd_word_trees(WORD, g)


def cmd_words(LANG, g):
    """List unicode strings for each word, or count all words, in language"""
    if not LANG: LANG = 'eng'
    iter_ = wn.words(LANG)
    items = list(iter_)
    if g.count:
        print(len(items))
    else:
        for w in u_o_ml('Words:', items, g):
            print(w)
            break
        print(type(w))


### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers(globals(), 'cmd_')
commands.update(dict(
        list = cmd_definitions,
        help = libcmd_docopt.cmd_help,
        memdebug = libcmd_docopt.cmd_memdebug
))


### Util functions to run above functions from cmdline

def wordnet_defaults(opts, init={}):
    global cmd_default_settings
    libcmd_docopt.defaults(opts)
    opts.flags.update(cmd_default_settings)
    opts.flags.update(dict(
        head = not opts.flags.no_head
    ))
    return init

def wordnet_main(opts):

    """
    Execute command.
    """
    global ctx, commands

    settings = opts.flags

    ret = libcmd_docopt.run_commands(commands, settings, opts)
    if settings.print_memory:
        libcmd_docopt.cmd_memdebug(settings)
    return ret

def wordnet_version():
    return 'wordnet.mpe/%s' % __version__


if __name__ == '__main__':
    import sys

    if os.getenv('TERM', None) == 'dumb':
        log.formatting_enabled = False

    opts = libcmd_docopt.get_opts(__description__+'\n'+__usage__,
            version=wordnet_version(), defaults=wordnet_defaults)
    sys.exit(wordnet_main(opts))
