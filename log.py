#!/bin/env python

def main(logfifo):
    logfp = open(logfifo)
    while True:

    for line in logfp.readline():
        print line

if __name__ == '__main__':
    import sys
    main(*sys.argv[1:])
