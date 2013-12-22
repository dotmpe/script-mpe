#!/usr/bin/env python
# via: http://www.howforge.com/fix-incorrect-filename-encoding
import sys
import os
from optparse import OptionParser

class Application:
    options = None
    args =[]

    def __init__(self):
        self.parse_args()

    def parse_args(self):
        parser = OptionParser(usage='usage: %prog [options] path ...')
        parser.add_option('-v','--verbose',dest='verbose',default=False,
                          action="store_true",help='verbose')
        parser.add_option('-i','--in',dest='in_encoding',default='latin-1',
                          help='input encoding (default=latin-1)')
        parser.add_option('-o','--out',dest='out_encoding',default='utf-8',
                          help='output encoding (default=utf-8)')
        parser.add_option('-r','--recursive',dest='recursive',default=False,
                          action="store_true",help='recursive')
        parser.add_option('--dryrun',dest='dryrun',default=False,
                          action="store_true",help='dry run')
        self.options, self.args = parser.parse_args(sys.argv)
        self.args.pop(0) # scriptname

    def verbose(self,message):
        if self.options.verbose:
            print message

    def error(self,message):
        print >> sys.stderr,'ERROR: %s' % message

    def run(self):
        for path in self.args:
            self.process(path)

    def process(self,path):
        if self.options.recursive:
            for root,dirs,files in os.walk(path,topdown=False):
                for name in files:
                    self.rename(os.path.join(root,name))
                for name in dirs:
                    self.rename(os.path.join(root,name))
        self.rename(path)

    def rename(self,path):
        path = os.path.realpath(path)
        dir = os.path.dirname(path)
        src = os.path.basename(path)

        dest = src.decode(self.options.in_encoding,'replace').encode(self.options.out_encoding,'replace')

        src = os.path.join(dir, src)
        dest = os.path.join(dir, dest)
        self.verbose("rename '%s' to '%s'" % (src,dest))
        try:
            if not self.options.dryrun:
                os.rename(src,dest)
        except OSError,why:
            self.error(str(why))

if __name__ == '__main__':
    app = Application()
    app.run()
# vim:set expandtab:
