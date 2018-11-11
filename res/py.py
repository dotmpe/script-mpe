"""
Uses parser from
<https://code.activestate.com/recipes/213898-drawing-inheritance-diagrams-with-dot/>
License: Python-like
"""
import os, itertools, re

# NOTE: some bin may be able to read PS stream directly
PSVIEWER='graphviz'     # you may change these with
PNGVIEWER='kview' # your preferred viewers
# Using generic file-open (OSX does a PDF conversion before showing with # Preview)
PSVIEWER = 'open'
PNGVIEWER = 'open'

PSFONT='Times'    # you may change these too
PNGFONT='Courier' # on my system PNGFONT=Times does not work


def if_(cond,e1,e2=''):
    "Ternary operator would be"
    if cond: return e1
    else: return e2

def MRO(cls):
    "Returns the MRO of cls as a text"
    out=["MRO of %s:" % cls.__name__]
    for counter,c in enumerate(cls.__mro__):
        name=c.__name__
        bases=','.join([b.__name__ for b in c.__bases__])
        s="  %s - %s(%s)" % (counter,name,bases)
        if type(c) is not type: s+="[%s]" % type(c).__name__
        out.append(s)
    return '\n'.join(out)


class MROgraph(object):

    def __init__(self,*classes,**options):
        "Generates the MRO graph of a set of given classes."
        if not classes: raise "Missing class argument!"
        filename=options.get('filename',"MRO_of_%s.ps" % (classes[0].__name__))
        if os.sep in filename:
            if filename.startswith(os.sep):
                filepath = filename
            else:
                filepath = os.path.join(os.curdir, filename)
        else:
            filepath = os.path.join(os.curdir, filename)
        name, dotformat = os.path.splitext(os.path.basename(filename))
        name = re.sub('[^A-Za-z0-9_]*', '_', name)
        self.labels=options.get('labels',2)
        caption=options.get('caption',False)
        setup=options.get('setup','')
        format=dotformat[1:]
        fontopt="fontname="+if_(format=='ps',PSFONT,PNGFONT)
        nodeopt=' node [%s];\n' % fontopt
        edgeopt=' edge [%s];\n' % fontopt
        viewer=if_(format=='ps',PSVIEWER,PNGVIEWER)
        self.textrepr='\n'.join([MRO(cls) for cls in classes])
        caption=if_(caption,
                   'caption [shape=box,label="%s\n",fontsize=9];'
                   % self.textrepr).replace('\n','\\l')
        setupcode=nodeopt+edgeopt+caption+'\n'+setup+'\n'
        codeiter=itertools.chain(*[self.genMROcode(cls) for cls in classes])

        self.dotcode='digraph %s{\n%s%s}' % (
            name,setupcode,'\n'.join(codeiter))
        os.system("echo '%s' | dot -T%s > %s" % (self.dotcode, format, filepath))
        if (options.get('view', False)):
            os.system("%s %s&" % (viewer, filename))

    def genMROcode(self,cls):
        "Generates the dot code for the MRO of a given class"
        for mroindex,c in enumerate(cls.__mro__):
            name=c.__name__
            manyparents=len(c.__bases__) > 1
            if c.__bases__:
                yield ''.join([
                    ' edge [style=solid]; %s -> %s %s;\n' % (
                    b.__name__,name,if_(manyparents and self.labels==2,
                                        '[label="%s"]' % (i+1)))
                    for i,b in enumerate(c.__bases__)])
            if manyparents:
                yield " {rank=same; %s}\n" % ''.join([
                    '"%s"; ' % b.__name__ for b in c.__bases__])
            number=if_(self.labels,"%s-" % mroindex)
            label='label="%s"' % (number+name)
            option=if_(issubclass(cls,type), # if cls is a metaclass
                       '[%s]' % label,
                       '[shape=box,%s]' % label)
            yield(' %s %s;\n' % (name,option))
            if type(c) is not type: # c has a custom metaclass
                metaname=type(c).__name__
                yield ' edge [style=dashed]; %s -> %s;' % (metaname,name)

    def __repr__(self):
        "Returns the Dot representation of the graph"
        return self.dotcode

    def __str__(self):
        "Returns a text representation of the MRO"
        return self.textrepr


def testHierarchy(**options):
    class M(type): pass # metaclass
    class F(object): pass
    class E(object): pass
    class D(object): pass
    class G(object): __metaclass__=M
    class C(F,D,G): pass
    class B(E,D): pass
    class A(B,C): pass
    return MROgraph(A,M,**options)


if __name__=="__main__":
    import sys
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)
        sys.exit(0)
    if '--test' in args:
        args.remove('--test')
        options = {}
        if '--view' in args:
            args.remove('--view')
            options.update(view=True)
        if args: options.update(filename=args.pop())
        testHierarchy(**options) # generates a postscript diagram of A and M hierarchies
    else:
        sys.exit(1)
