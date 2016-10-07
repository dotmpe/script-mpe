#!/usr/bin/env python
import sys

#s1, s2, s3, s4 = "Foo", "Bar", "Baz", "spam"
#
#
#print ' '*4,
#print " 30m",
#print " 31m",
#print " 32m",
#print " 33m",
#print " 34m",
#print " 35m",
#print " 36m",
#print " 37m",
#print " 38m"
#print ' fg ',
#print "\x1b[30m  30\x1b[0m",
#print "\x1b[31m  31\x1b[0m",
#print "\x1b[32m  32\x1b[0m",
#print "\x1b[33m  33\x1b[0m",
#print "\x1b[34m  34\x1b[0m",
#print "\x1b[35m  35\x1b[0m",
#print "\x1b[36m  36\x1b[0m",
#print "\x1b[37m  37\x1b[0m", 
#print "\x1b[38m  38\x1b[0m", " normal"
#print '  1 ',
#print "\x1b[1;30m1,30\x1b[0m",
#print "\x1b[1;31m1,31\x1b[0m",
#print "\x1b[1;32m1,32\x1b[0m",
#print "\x1b[1;33m1,33\x1b[0m",
#print "\x1b[1;34m1,34\x1b[0m",
#print "\x1b[1;35m1,35\x1b[0m",
#print "\x1b[1;36m1,36\x1b[0m",
#print "\x1b[1;37m1,37\x1b[0m", " bright"
#print '  2 ',
#print "\x1b[2;30m2,30\x1b[0m",
#print "\x1b[2;31m2,31\x1b[0m",
#print "\x1b[2;32m2,32\x1b[0m",
#print "\x1b[2;33m2,33\x1b[0m",
#print "\x1b[2;34m2,34\x1b[0m",
#print "\x1b[2;35m2,35\x1b[0m",
#print "\x1b[2;36m2,36\x1b[0m",
#print "\x1b[2;37m2,37\x1b[0m", " faint"
#print '  3 ',
#print "\x1b[3;30m3,30\x1b[0m",
#print "\x1b[3;31m3,31\x1b[0m",
#print "\x1b[3;32m3,32\x1b[0m",
#print "\x1b[3;33m3,33\x1b[0m",
#print "\x1b[3;34m3,34\x1b[0m",
#print "\x1b[3;35m3,35\x1b[0m",
#print "\x1b[3;36m3,36\x1b[0m",
#print "\x1b[3;37m3,37\x1b[0m", " italic"
#print '  4 ',
#print "\x1b[4;30m4,30\x1b[0m",
#print "\x1b[4;31m4,31\x1b[0m",
#print "\x1b[4;32m4,32\x1b[0m",
#print "\x1b[4;33m4,33\x1b[0m",
#print "\x1b[4;34m4,34\x1b[0m",
#print "\x1b[4;35m4,35\x1b[0m",
#print "\x1b[4;36m4,36\x1b[0m",
#print "\x1b[4;37m4,37\x1b[0m", " underline"
#print '  5 ',
#print "\x1b[5;30m5,30\x1b[0m",
#print "\x1b[5;31m5,31\x1b[0m",
#print "\x1b[5;32m5,32\x1b[0m",
#print "\x1b[5;33m5,33\x1b[0m",
#print "\x1b[5;34m5,34\x1b[0m",
#print "\x1b[5;35m5,35\x1b[0m",
#print "\x1b[5;36m5,36\x1b[0m",
#print "\x1b[5;37m5,37\x1b[0m", " blink <150/minute"
#print '  6 ',    
#print "\x1b[6;30m6,30\x1b[0m",
#print "\x1b[6;31m6,31\x1b[0m",
#print "\x1b[6;32m6,32\x1b[0m",
#print "\x1b[6;33m6,33\x1b[0m",
#print "\x1b[6;34m6,34\x1b[0m",
#print "\x1b[6;35m6,35\x1b[0m",
#print "\x1b[6;36m6,36\x1b[0m",
#print "\x1b[6;37m6,37\x1b[0m", " blink >150/minute "
#print '  7 ',
#print "\x1b[7;30m7,30\x1b[0m",
#print "\x1b[7;31m7,31\x1b[0m",
#print "\x1b[7;32m7,32\x1b[0m",
#print "\x1b[7;33m7,33\x1b[0m",
#print "\x1b[7;34m7,34\x1b[0m",
#print "\x1b[7;35m7,35\x1b[0m",
#print "\x1b[7;36m7,36\x1b[0m",
#print "\x1b[7;37m7,37\x1b[0m", " image negative"
#print '  8 ',
#print "\x1b[8;30m8,30\x1b[0m",
#print "\x1b[8;31m8,31\x1b[0m",
#print "\x1b[8;32m8,32\x1b[0m",
#print "\x1b[8;33m8,33\x1b[0m",
#print "\x1b[8;34m8,34\x1b[0m",
#print "\x1b[8;35m8,35\x1b[0m",
#print "\x1b[8;36m8,36\x1b[0m",
#print "\x1b[8;37m8,37\x1b[0m", " conceal"
#print '  9 ',
#print "\x1b[9;30m9,30\x1b[0m",
#print "\x1b[9;31m9,31\x1b[0m",
#print "\x1b[9;32m9,32\x1b[0m",
#print "\x1b[9;33m9,33\x1b[0m",
#print "\x1b[9;34m9,34\x1b[0m",
#print "\x1b[9;35m9,35\x1b[0m",
#print "\x1b[9;36m9,36\x1b[0m",
#print "\x1b[9;37m9,37\x1b[0m", " crossed-out"
#print ' bg ',
#print "\x1b[40m  40\x1b[0m",
#print "\x1b[41m  41\x1b[0m",
#print "\x1b[42m  42\x1b[0m",
#print "\x1b[43m  43\x1b[0m",
#print "\x1b[44m  44\x1b[0m",
#print "\x1b[45m  45\x1b[0m",
#print "\x1b[46m  46\x1b[0m",
#print "\x1b[47m  47\x1b[0m", " normal"
#print '  1 ',
#print "\x1b[1;40m1,40\x1b[0m",
#print "\x1b[1;41m1,41\x1b[0m",
#print "\x1b[1;42m1,42\x1b[0m",
#print "\x1b[1;43m1,43\x1b[0m",
#print "\x1b[1;44m1,44\x1b[0m",
#print "\x1b[1;45m1,45\x1b[0m",
#print "\x1b[1;46m1,46\x1b[0m",
#print "\x1b[1;47m1,47\x1b[0m"
#print '  2 ',    
#print "\x1b[2;40m2,40\x1b[0m",
#print "\x1b[2;41m2,41\x1b[0m",
#print "\x1b[2;42m2,42\x1b[0m",
#print "\x1b[2;43m2,43\x1b[0m",
#print "\x1b[2;44m2,44\x1b[0m",
#print "\x1b[2;45m2,45\x1b[0m",
#print "\x1b[2;46m2,46\x1b[0m",
#print "\x1b[2;47m2,47\x1b[0m",
#print "\x1b[2;48m2,48\x1b[0m"
#print '  3 ',    
#print "\x1b[3;40m3,40\x1b[0m",
#print "\x1b[3;41m3,41\x1b[0m",
#print "\x1b[3;42m3,42\x1b[0m",
#print "\x1b[3;43m3,43\x1b[0m",
#print "\x1b[3;44m3,44\x1b[0m",
#print "\x1b[3;45m3,45\x1b[0m",
#print "\x1b[3;46m3,46\x1b[0m",
#print "\x1b[3;47m3,47\x1b[0m"
#print '  4 ',    
#print "\x1b[4;40m4,40\x1b[0m",
#print "\x1b[4;41m4,41\x1b[0m",
#print "\x1b[4;42m4,42\x1b[0m",
#print "\x1b[4;43m4,43\x1b[0m",
#print "\x1b[4;44m4,44\x1b[0m",
#print "\x1b[4;45m4,45\x1b[0m",
#print "\x1b[4;46m4,46\x1b[0m",
#print "\x1b[4;47m4,47\x1b[0m"
#print '  5 ',    
#print "\x1b[5;40m5,40\x1b[0m",
#print "\x1b[5;41m5,41\x1b[0m",
#print "\x1b[5;42m5,42\x1b[0m",
#print "\x1b[5;43m5,43\x1b[0m",
#print "\x1b[5;44m5,44\x1b[0m",
#print "\x1b[5;45m5,45\x1b[0m",
#print "\x1b[5;46m5,46\x1b[0m",
#print "\x1b[5;47m5,47\x1b[0m"
#print '  6 ',    
#print "\x1b[6;40m6,40\x1b[0m",
#print "\x1b[6;41m6,41\x1b[0m",
#print "\x1b[6;42m6,4r\x1b[0m",
#print "\x1b[6;43m6,43\x1b[0m",
#print "\x1b[6;44m6,44\x1b[0m",
#print "\x1b[6;45m6,45\x1b[0m",
#print "\x1b[6;46m6,46\x1b[0m",
#print "\x1b[6;47m6,47\x1b[0m"
#print '  7 ',    
#print "\x1b[7;40m7,40\x1b[0m",
#print "\x1b[7;41m7,41\x1b[0m",
#print "\x1b[7;42m7,42\x1b[0m",
#print "\x1b[7;43m7,43\x1b[0m",
#print "\x1b[7;44m7,44\x1b[0m",
#print "\x1b[7;45m7,45\x1b[0m",
#print "\x1b[7;46m7,46\x1b[0m",
#print "\x1b[7;47m7,47\x1b[0m",
#print "\x1b[7;48m7,48\x1b[0m"
#print '  8 ',    
#print "\x1b[8;40m8,40\x1b[0m",
#print "\x1b[8;41m8,41\x1b[0m",
#print "\x1b[8;42m8,42\x1b[0m",
#print "\x1b[8;43m8,43\x1b[0m",
#print "\x1b[8;44m8,44\x1b[0m",
#print "\x1b[8;45m8,45\x1b[0m",
#print "\x1b[8;46m8,46\x1b[0m",
#print "\x1b[8;47m8,47\x1b[0m",
#print "\x1b[8;48m8,48\x1b[0m"
#print '  9 ',    
#print "\x1b[9;40m9,40\x1b[0m",
#print "\x1b[9;41m9,41\x1b[0m",
#print "\x1b[9;42m9,42\x1b[0m",
#print "\x1b[9;43m9,43\x1b[0m",
#print "\x1b[9;44m9,44\x1b[0m",
#print "\x1b[9;45m9,45\x1b[0m",
#print "\x1b[9;46m9,46\x1b[0m",
#print "\x1b[9;47m9,47\x1b[0m",
#print "\x1b[9;48m9,48\x1b[0m"



def code(*digits):
    return "\x1b[%sm" % ';'.join(map(str, digits))


# bright, faint, italic, underline
STYLES = (0, 20, 'normal'), (1, 21, 'bright'), (2, 22, 'faint'), (3, 23, 'italic'), (4, \
        24, 'underline'), (5, 25, 'blink <150/minute'), (6, 26, 'blink >150/min'), \
                        (7, 27, 'image negative'),  (8, 29, 'conceal'), (9, 29, 'crossed-out')

for attr in STYLES:
    print attr[2]
    print "          ".join(map(str, range(40, 49))), '       < backround / V foreground'
    for fg in range(30, 39):
        for bg in range(40, 49):
            print code(attr[0]), code(fg, bg), attr[0], fg, '  ',  code(attr[1]), code(0),
        print

print code(0)




