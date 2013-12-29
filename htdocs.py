#!/usr/bin/env python
"""
TODO: construct TopicTree from Definition Lists in restructured text. 
See also filetree.
"""
import os

from dotmpe.du import comp, frontend

from libname import Namespace, Name
from libcmd import Targets, Arguments, Keywords, Options,\
    Target 
import libcmd



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
    DEFAULT_CONFIG_KEY = 'htdocs'
    DEFAULT_ACTION = 'status'
        
    def __init__(self):
        super(Htdocs, self).__init__()

    def status(self, sa=None, args=None):
        # XXX print frontend.cli_process(source, builder_name='htdocs')
        B = comp.get_builder_class('dotmpe.du.builder.htdocs')
        #B = comp.get_builder_class('dotmpe.du.builder.dotmpe_v5')
        B.extractor_spec = [
                ('dotmpe.du.ext.extractor.htdocs.HtdocsExtractor', 'htdocs.TempStorage')
            ]
        store_params = {
                #'HtdocsStorage': ((), dict(dbref=)),
                'htdocs.TempStorage': (( sa, ), dict()),
            }
        b = B()
        b.prepare_extractors(**store_params)
        for source in args:
            document = b.build(open(source).read())
            print b.process(document)
            #print b.process(open(source).read())
        #comp.get_builder_class('dotmpe.du.builder.htdocs')
        #print args, frontend.cli_process(args, builder_name='dotmpe.du.builder.mpe')

    def update(self, args=None, sa=None):
        print args

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
                (('--status',), libcmd.cmddict()),
                (('--update',), libcmd.cmddict()),
            )


if __name__ == '__main__':
    Htdocs.main()
