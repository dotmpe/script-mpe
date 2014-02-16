"""
XXX: can I improve htdocs.py, or should that finish first

Model
    ID
        Localpath
            - netpath

    Node
        - name

        RstDoc
            - builder : [ "standalone" ]
        Topic
            ..
        Day
            - gregorian

"""
import os
import libcmd


class Rsr(libcmd.StackedCommand):

    NAME = os.path.splitext(os.path.basename(__file__))[0]
    assert NAME == 'rsr'
    
    DEFAULT_RC = 'cllct.rc'
    DEFAULT = [ 'rsr_info' ]

    def rsr_info(self):
        pass

if __name__ == '__main__':
    Rsr.main()

