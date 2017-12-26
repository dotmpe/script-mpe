from nltk.corpus import wordnet as wn



def syn_or_syns(word):
    if '.' in word:
        syn = wn.synset(word)
        syns = [ syn ]
    else:
        syn = None
        syns = wn.synsets(word)
    return syn, syns


def short_def(s):
    lemmas = ", ".join( s.lemma_names() )
    return lemmas + " (%s; %s)"%( s.lexname(), s.name(), )


INDENT = 2

def print_short_def(s, d=0, i=None):
    if i != None:
        indent = (str(i+1)+'. ').ljust(d*INDENT)
    else:
        indent = (' '*INDENT*d)
    print( indent + short_def(s) )


def print_word_tree(s, t=None, d=0, i=None):
    print_short_def(s, d=d, i=i)
    if t:
        for x in t:
            if isinstance(x, list):
                s2 = x.pop(0)
                if not x:
                    print_word_tree(s2, d=d+1)
                for t2 in x:
                    print_word_tree(s2, t2, d+1)
            else:
                print_word_tree(x, d=d+1)


def printcmd_word_trees(WORD, g):
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    d = 0
    if g.head:
        print(WORD)
        d = 1
    for i, s in enumerate(syns):
        d_ = d
        if syn: i=None
        else: d_ = d+1
        print_word_tree(s, s.tree(lambda s: s.hypernyms()), d=d_, i=i)

def printcmd_word_meanings(WORD, g):
    if not WORD: return 1
    syn, syns = syn_or_syns(WORD)

    d = 0
    if g.head:
        print(WORD)
        d = 1
    for i, s in enumerate(syns):
        d_ = d
        if syn: i=None
        else: d_ = d+1
        print_short_def(s, d=d_, i=i)
        print((' '*INDENT*(1+d))+s.definition())


def position_label(s):
    return ({
        wn.ADJ: 'adj',
        wn.ADJ_SAT: 'adj-sat',
        wn.ADV: 'adv',
        wn.NOUN: 'n',
        wn.VERB: 'verb'
    })[s.pos()]
