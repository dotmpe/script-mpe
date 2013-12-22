#!/usr/bin/env python
"""
"""
import os
import sys

import dotmpe.du
from dotmpe.du import frontend
import dotmpe.du.ext




def main(argv=sys.argv):
    print frontend.cli_process(argv[1:], 'dotmpe.du.builder.dotmpe_v5')


if __name__ == '__main__':
    main()
