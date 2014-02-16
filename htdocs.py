#!/usr/bin/env python
"""
TODO: construct TopicTree from Definition Lists in restructured text. 
See also filetree.

FIXME: move something like a definition parser to elsewhere? something simple
    and lightweight perhaps to fit rsrlib.res,
"""
import os

from dotmpe.du import comp, frontend

#from script_mpe import res
import log
import confparse
import res.fs
from libname import Namespace
import libcmd
from libcmdng import Targets, Arguments, Keywords, Options,\
    Target 
import traceback



NS = Namespace.register(
        prefix='htdocs',
        uriref='http://project.dotmpe.com/script/#/htdocs'
    )

Options.register(NS, 
#                (('--init-host',), libcmd.cmddict(help="TODO"))
        )


@Target.register(NS, 'update', 'txs:session')
def htdocs_update(args=None, sa=None, ur=None, opts=None, settings=None):
    """
    TODO:
    - store daily items in x-index somehow, it could take the form of
      journal per topic (note/project/...) or only a list of references attached
      at the topic..
    
    """
    # defer to class
    htd = Htdocs()
    return htd.status(args=args, sa=sa)


from nabu import extract
#from dotmpe.du.ext import extract


class TempStorage(extract.ExtractorStorage):

    def __init__(self, sa):
        self.sa = sa


# XXX libcmd is not working all-ok yet (for TargetResolver)
# using SimpleCommand too and keep both working as long as feasible/convenient

class Htdocs(libcmd.SimpleCommand):

    PROG_NAME = os.path.splitext(os.path.basename(__file__))[0]
    VERSION = "0.1"
    USAGE = """Usage: %prog [options] paths """

    DEFAULT = [ 'status' ]
    #DEFAULT_CONFIG_KEY = 'htdocs'
        
    def __init__(self):
        super(Htdocs, self).__init__()

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
                (('--status',), libcmd.cmddict()),
                (('--update',), libcmd.cmddict()),
            )

    def status(self, sa=None, *paths):
        """
        Work in progress: run over documents and store extractor results.
        """
        # XXX print frontend.cli_process(source, builder_name='htdocs')
        B = comp.get_builder_class('dotmpe.du.builder.htdocs')
        #B = comp.get_builder_class('dotmpe.du.builder.dotmpe_v5')
        B.extractor_spec = [ (
            'dotmpe.du.ext.extractor.reference.Extractor',
                    'dotmpe.du.ext.extractor.TransientStorage'
        ), (
            'dotmpe.du.ext.extractor.htdocs.HtdocsExtractor',
                    'dotmpe.du.ext.extractor.TransientStorage'
        ) ]
        store_params = {
            #'HtdocsStorage': ((), dict(dbref=)),
            'dotmpe.du.ext.extractor.TransientStorage': (( {}, 'results', ), dict()),
        }
        b = B()
        b.prepare_extractors(**store_params)

        sources = []

        for path in paths:
            if os.path.isdir(path):
                walk_opts = res.fs.Dir.walk_opts.copy()
                walk_opts.update(dict(recurse=True, files=True))
                sources_ = list( res.fs.Dir.walk(path,
                    confparse.Values(walk_opts)))
                [ sources.append(s) for s in sources_ if s.endswith('.rst') ]
            elif os.path.isfile(path):
                if path.endswith('.rst'):
                    sources.append(path)

        for source in sources:
            document = None
            print 'source', source
            try:
                document = b.build(source=open(source).read(), source_id=source)
            except:
                #print 'error building %s' % source
                traceback.print_exc()
                log.err('building %s', source)
                continue
            try:
                b.process(document)
            except:
                #print 'error processing', source
                traceback.print_exc()
                log.err('processing %s', source)
                continue
        ts = b.extractors[0][1]
        print 'ts.results', ts.results, self
            #print b.process(open(source).read())
        #comp.get_builder_class('dotmpe.du.builder.htdocs')
        #print args, frontend.cli_process(args, builder_name='dotmpe.du.builder.mpe')

    def update(self, sa=None, *args):
        print args


if __name__ == '__main__':
    Htdocs.main()
