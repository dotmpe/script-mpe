#!/usr/bin/env python
from script_mpe.libhtd import *
from script_mpe.libcmd import *

if __name__ == '__main__':
    if StackedCommand.NAME == 'libcmd_stacked':
        StackedCommand.NAME = 'libcmd'
        StackedCommand.DEFAULT_RC = 'libcmdrc'
        StackedCommand.main()
    else:
        SimpleCommand.main()
