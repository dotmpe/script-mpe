#!/usr/bin/env python
import zope

import dotmpe.du.comp

import libcmd
import res


class mkDoc(libcmd.SimpleCommand):
    """
    Nov. 2013. Another iteration of mkdoc: cross-index/xform personal documents.
    """
    zope.interface.implements(res.iface.ISimpleCommand)

    BOOTSTRAP =  ['static_args','path_args','run_commands']
    DEFAULT = ['run_files']

    @classmethod
    def get_optspec(klass, inherit):
        """
        Return tuples with optparse command-line argument specification.
        """
        return (
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
            
                        

if __name__ == '__main__':
    mkDoc.main()

