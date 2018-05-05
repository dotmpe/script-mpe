#!/usr/bin/env python
from script_mpe.libhtd import *
from script_mpe.libcmd import *

if __name__ == '__main__':
    if StackedCommand.NAME == 'libcmd_stacked_test':
        StackedCommand.NAME = 'libcmd_test'
        StackedCommand.DEFAULT_RC = 'libcmdrc'
        StackedCommand.main()
    else:
        SimpleCommand.NAME = 'libcmd_test'
        SimpleCommand.main()
