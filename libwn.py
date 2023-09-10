"""
:Created: 2017
:Updated: 2020

Some utils for nltk.corpus to query WordNet dataset, and output helpers for
wordnet.py

Wordnet has definitions and relations between 'sense' terms, and can return
a list of such terms given a word. For example, if we look for the definition
of 'word' we get 11 'Synset' items. The Python documentation explains this type
and the database in more detail\ [#]_. The summary for here is that aside from
any english word, a query with the following format is possible and which will
return one specific definition only instead of a set:

    <lemma>.<pos>.<number>

Position tells about the use of the word together with others.
So we say they can be nouns and verbs, or ajdectives, adverbs, and adjective sattelites.
(If you know what all that is.)
All numbers tells us how many definitions there are.

The output of 'wordnet.py define word.n.01'::

  WORD. (noun.communication; word.n.01): a unit of language that native speakers can identify
    n. a unit of language that native speakers can identify

      "words are the blocks from which sentences are made"
      "he hardly said ten words all morning"

As you can see in the dump from 'wordnet info word.n.01' as well,
there is a lot of stuff that can be queried.

.. [#] See pydoc nltk.corpus.reader.wordnet.Synset
"""
# Get nltk.corpus.reader.api.CorpusReader instance, prepared by nltk module
from nltk.corpus import wordnet as wn

from script_mpe import log


def syn_or_syns(word):
    """
    Retrieves synonym sets for words, or a specific sense given a synset name.
    """
    if '.' in word:
        syn = wn.synset(word)
        syns = [ syn ]
    else:
        syn = None
        syns = wn.synsets(word)
    return syn, syns


synset_field_attr_map = (
        ('Definition', 'definition', 0),
        ('Examples', 'examples', 4),
        ('Entailments', 'entailments', 1),
        ('Similar to', 'similar_tos', 1),
        ('See also', 'also_sees', 1),
        ('Lexicographer filename', 'lexname', 0),
        ('Offset', 'offset', 0),
        ('Frame IDs', 'frame_ids', 4),
        ('Attributes', 'attributes', 1),
        ('Max depth', 'max_depth', 0),
        ('Verb groups', 'verb_groups', 1),
        ('Hyponyms', 'hyponyms', 1),
        ('Hyponyms (instance)', 'instance_hyponyms', 1),
        ('Hypernyms', 'hypernyms', 1),
        ('Hypernyms (instance)', 'instance_hypernyms', 1),
        ('Hypernyms (root)', 'root_hypernyms', 1),
        ('Hypernym distances', 'hypernym_distances', 2),
        ('Hypernym paths', 'hypernym_paths', 3),
        #('Hypernym (common)', 'common_hypernyms', 1),
        #('Hypernym (lowest common)', 'lowest_common_hypernyms', 1),
        ('Holonyms (substance)', 'substance_holonyms', 1),
        ('Holonyms (member)', 'member_holonyms', 1),
        ('Holonyms (part)', 'part_holonyms', 1),
        ('Meronyms (substance)', 'substance_meronyms', 1),
        ('Meronyms (member)', 'member_meronyms', 1),
        ('Meronyms (part)', 'part_meronyms', 1),
        ('Topic domains', 'topic_domains', 1),
        ('Region domains', 'region_domains', 1),
        ('Usage domains', 'usage_domains', 1),
        #('Hypernym (common)', 'common_hypernyms', 0),
    )

# Helpers to traverse WN parts and chat about it on stderr, and print formatted
# results to stdout

INDENT = 2

def print_short_def(s, d=0, i=None, w=None):
    if i != None:
        indent = (str(i+1)+'. ').ljust(d*INDENT)
    else:
        indent = (' '*INDENT*d)
    log.stdout( indent + short_def(s, w=w) + '{default}' )


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
        log.stdout('{green}'+WORD+'{default}')
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
        log.stdout('{green}'+WORD+'{default}')
        d = 1
    for i, s in enumerate(syns):
        d_ = d
        if syn: i=None
        else: d_ = d+1
        print_short_def(s, d=d_, i=i, w=WORD)
    log.stdout('{default}')


# Helpers to process WN parts

def u_q_w(WORD, g):
    "user-query-word handler"
    if not WORD: return 1, ()
    syn, syns = syn_or_syns(WORD)
    if not syn and not syns:
        log.stderr('{yellow}No results{default}')
        return 1, ( None, None )
    return 0, (syn, syns)

def u_o_ml(fieldlabel, listval, g):
    "user-o-maxlist"
    if not len(listval):
        return ()

    msl = int(g.max_sublist)
    if len(listval) > msl:
        # FIXME: not every set has an index
        #print('%s (%i more):' % (fieldlabel, len(listval)-msl))
        #return listval[:msl]
        pass

    print('%s (%i):' % (fieldlabel, len(listval)))
    return listval

def short_def(s, w=None):
    lemmas = ", ".join( [ n for n in s.lemma_names() if n != w] )
    info = "{blue}({yellow}%s{blue}; {magenta}%s{blue}): {cyan}%s{blue}"%(
            s.lexname(), s.name(), s.definition())
    if lemmas:
        return '{green}'+lemmas +' '+ info
    return info

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
    return "%s#%i" % (name, num)
    # XXX return "%s{blue}({yellow}%i{blue})" % (name, num)
