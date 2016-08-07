#!/usr/bin/env python
import os, sys, numpy



sizes = []
for line in sys.stdin.readlines():
    path = os.path.abspath(line.strip())
    if not (os.path.exists(path) and os.path.isfile(path)):
        continue
    size = os.path.getsize(path)
    sizes.append( size )


lsizes = len(sizes)
print lsizes, 'Sizes'

_1k = 1024
_4k = 1024 * 4
_1M = 1024 * 1024
_4M = 1024 * 1024 * 4
_14M = 1024 * 1024 * 14
_128M = 1024 * 1024 * 128
_4G  = 1024 * 1024 * 1024 * 4
_1T = 1024 * 1024 * 1024 * 1024

bins = [ 0, _1k, _4k, _1M, _4M, _14M, _128M, _4G, _1T ]
labels = "0b 1k 4k 1M 4M 14M 128M 4G 1T".split(' ')

hist, edges = numpy.histogram( sizes, bins=bins )

print len(hist), 'bins'

print

for i, bin in enumerate(hist):
    print labels[i], "%.1f" % ((bin * 100.0) / lsizes)
    #print labels[i], len(bin)


if __name__ == '__main__':
    pass

