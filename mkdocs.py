#!/usr/bin/env python
"""
"""
from __future__ import print_function
import zope

import dotmpe.du.comp

import libcmd
import res

from nabu import extract
#from dotmpe.du.ext import extract


class TempStorage(extract.ExtractorStorage):

    def __init__(self, sa):
        self.sa = sa


class mkDoc(libcmd.SimpleCommand):

    """
    Nov. 2013. Another iteration of mkdoc: cross-index/xform personal documents.
    """
    zope.interface.implements(res.iface.ISimpleCommand)

    BOOTSTRAP = ['static_args','path_args','set_commands']
    DEFAULT = ['run_files']

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
                (('--status',), libcmd.cmddict()),
            )

    def run_files(self, prog, *args):
        build = dotmpe.du.comp.get_builder_class('mkdoc')
        builder = build()
        for a in args:
            # XXX: replace once possible
            #dotmpe.du.core.process( a, builder='mkdoc')
            #dotmpe.du.core.publish( a, reader='mkdoc', parser='rst', writer='formresults' )
            #
            document = builder.build( a, source_class=io.FileInput, reader='mkdoc' )


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
                'dotmpe.du.ext.extractor.TransientStorage': (
                    ( {}, 'results', ), dict()
                ),
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
            print('source', source)
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
        print('ts.results', ts.results, self)
            #print b.process(open(source).read())
        #comp.get_builder_class('dotmpe.du.builder.htdocs')
        #print args, frontend.cli_process(args, builder_name='dotmpe.du.builder.mpe')

    def update(self, sa=None, *args):
        print(args)


if __name__ == '__main__':
    mkDoc.main()
