from nltk.corpus import wordnet as wn

import log


def syn_or_syns(word):
    if '.' in word:
        syn = wn.synset(word)
        syns = [ syn ]
    else:
        syn = None
        syns = wn.synsets(word)
    return syn, syns


def short_def(s, w=None):
    lemmas = ", ".join( [ n for n in s.lemma_names() if n != w] )
    info = "{blue}({yellow}%s{blue}; {magenta}%s{blue}): {cyan}%s{blue}"%(
            s.lexname(), s.name(), s.definition())
    if lemmas:
        return '{green}'+lemmas +' '+ info
    return info


INDENT = 2

def print_short_def(s, d=0, i=None, w=None):
    if i != None:
        indent = (str(i+1)+'. ').ljust(d*INDENT)
    else:
        indent = (' '*INDENT*d)
    log.stdout( indent + short_def(s, w=w) )


def print_word_tree(s, t=None, d=0, i=None, w=None):
    print_short_def(s, d=d, i=i, w=w)
    if t:
        for x in t:
            if isinstance(x, list):
                s2 = x.pop(0)
                if not x:
                    print_word_tree(s2, d=d+1, w=w)
                for t2 in x:
                    print_word_tree(s2, t2, d+1, w=w)
            else:
                print_word_tree(x, d=d+1, w=w)
    log.stdout('{default}')

def printcmd_word_trees(WORD, g):
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    d = 0
    if g.head:
        if syn:
            WORD = wn_sense(WORD, syn)
        log.stdout('{green}'+WORD+'{blue}')
        d = 1
    for i, s in enumerate(syns):
        d_ = d
        if syn: i=None
        else: d_ = d+1
        print_word_tree(s, s.tree(lambda s: s.hypernyms()), d=d_, i=i, w=WORD)

def printcmd_word_meanings(WORD, g):
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    d = 0
    if g.head:
        if syn:
            WORD = wn_sense(WORD, syn)
        log.stdout('{green}'+WORD+'{blue}')
        d = 1
    for i, s in enumerate(syns):
        d_ = d
        if syn: i=None
        else: d_ = d+1
        print_short_def(s, d=d_, i=i, w=WORD)
    log.stdout('{default}')

wn_positions_abbrev = {
        wn.ADJ: 'adj.',
        wn.ADJ_SAT: 'adj.sat.',
        wn.ADV: 'adv.',
        wn.NOUN: 'n.',
        wn.VERB: 'v.'
    }

wn_positions_label = {
        wn.ADJ: 'adjective',
        wn.ADJ_SAT: 'adjective sattelite',
        wn.ADV: 'adverb',
        wn.NOUN: 'noun',
        wn.VERB: 'verb'
    }

def position_label(s, abbrev=True):
    if abbrev:
        return wn_positions_abbrev[s.pos()]
    else:
        return wn_positions_label[s.pos()]

def traverse_hypernyms(s, d=0):
    for s_ in s.hypernyms():
        yield d, s_
        for d_, s__ in traverse_hypernyms(s_, d=d+1):
            yield d_, s__

def wn_sense(word, syn):
    assert syn or '.' in word, word
    if not word:
        assert syn
        word = syn.name()
    name = word.split('.')[0]
    num = int(word.split('.')[2])
    return "%s(%i)" % (name, num)
    # XXX return "%s{blue}({yellow}%i{blue})" % (name, num)
