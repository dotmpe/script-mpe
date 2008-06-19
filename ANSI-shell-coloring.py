#!/usr/bin/env python
import sys

s1, s2, s3, s4 = "Foo", "Bar", "Baz", "spam"


print "31m",
print "32m",
print "33m",
print "34m ",
print "35m ",
print "36m ",
print "37m "
print "\x1b[31m%s\x1b[0m" % (s1),
print "\x1b[32m%s\x1b[0m" % (s2),
print "\x1b[33m%s\x1b[0m" % (s3),
print "\x1b[34m%s\x1b[0m" % (s4),
print "\x1b[35m%s\x1b[0m" % (s4),
print "\x1b[36m%s\x1b[0m" % (s4),
print "\x1b[37m%s\x1b[0m" % (s4)
print "\x1b[1;31m%s\x1b[0m" % (s1),
print "\x1b[1;32m%s\x1b[0m" % (s2),
print "\x1b[1;33m%s\x1b[0m" % (s3),
print "\x1b[1;34m%s\x1b[0m" % (s4),
print "\x1b[1;35m%s\x1b[0m" % (s4),
print "\x1b[1;36m%s\x1b[0m" % (s4),
print "\x1b[1;37m%s\x1b[0m" % (s4)
print "\x1b[41m%s\x1b[0m" % (s1),
print "\x1b[42m%s\x1b[0m" % (s2),
print "\x1b[43m%s\x1b[0m" % (s3),
print "\x1b[44m%s\x1b[0m" % (s4),
print "\x1b[45m%s\x1b[0m" % (s4),
print "\x1b[46m%s\x1b[0m" % (s4),
print "\x1b[47m%s\x1b[0m" % (s4)
print "\x1b[1;41m%s\x1b[0m" % (s1),
print "\x1b[1;42m%s\x1b[0m" % (s2),
print "\x1b[1;43m%s\x1b[0m" % (s3)
print "\x1b[2;41m%s\x1b[0m" % (s1),
print "\x1b[2;42m%s\x1b[0m" % (s2)
print "\x1b[3;41m%s\x1b[0m" % (s1)

