#!/usr/bin/env python
from libcmd import Cmd
from taxus import Taxus
from rsr import Rsr


class Main(Taxus):

    def __init__(self):
        super(Main, self)

    @classmethod
    def get_opts(klass):
        return ()

    @staticmethod
    def get_options():
        return Cmd.get_opts() + Taxus.get_opts() + Rsr.get_opts()

if __name__ == '__main__':
    Main().main()


