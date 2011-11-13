#!/bin/env python
#
# An output colorizer for syslog.
# 
# $template custom,"TS:%timereported%;PRI:%pri%;PRI-text:%PRI-text%;APP:%app-name%;PID:%procid%;MID:%msgid%;HOSTNAME:%hostname%;msg:%msg%;FROMHOST:%FROMHOST%;STRUCTURED-DATA:%STRUCTURED-DATA%\n"
#
c00="\x1b[0;0;30m" # black/grey
c10="\x1b[0;1;30m" #
c01="\x1b[0;0;31m" # red
c11="\x1b[0;1;31m" #
c02="\x1b[0;0;32m" # green
c12="\x1b[0;1;32m" #
c03="\x1b[0;0;33m" # yellow
c13="\x1b[0;1;33m" #
c04="\x1b[0;0;34m" # blue
c14="\x1b[0;1;34m" # 
c05="\x1b[0;0;35m" # magenta/purple
c15="\x1b[0;1;35m" # 
c06="\x1b[0;0;36m" # cyan/light blue
c16="\x1b[0;1;36m" # 
c07="\x1b[0;0;37m" # white
c17="\x1b[0;1;37m" # 

palette = {}
palette.update(locals())

format = "c04,TS,c16,PRI,c05,HOSTNAME,c17,msg,c00"
error1 = "c00,TS,c10,PRI,c05,HOSTNAME,c11,msg,c00"

level_templates = {
    'emerg':  "c11,TS,c05, ,HOSTNAME, ,FAC,.,c11,LVL, ,c01,msg,c00",
    'alert':  "c13,TS,c05, ,HOSTNAME, ,FAC,.,c11,LVL, ,c07,msg,c00",
    'crit':   "c13,TS,c05, ,HOSTNAME, ,FAC,.,c11,LVL, ,c07,msg,c00",
    'err':    "c03,TS,c05, ,HOSTNAME, ,FAC,.,c01,LVL, ,c07,msg,c00",
    'warn':   "c03,TS,c05, ,HOSTNAME, ,FAC,.,c03,LVL, ,c07,msg,c00",
    'notice': "c07,TS,c05, ,HOSTNAME, ,FAC,.,c07,LVL, ,c07,msg,c00",
    'info':   "c00,TS,c05, ,HOSTNAME, ,FAC,.,c10,LVL, ,c07,msg,c00",
    'debug':  "c00,TS,c05, ,HOSTNAME, ,FAC,.,c10,LVL, ,c00,msg,c00",
}

def _format(fields):
#    return "; ".join(map(":".join,fields.items()))
    facility, level = fields['PRI-text'].split('<')[0].split('.')
    fields['FAC'] = facility
    fields['LVL'] = level
    template = "".join(map("%%(%s)s".__mod__,level_templates[level].split(",")))
    fields.update(palette)
    fields[' '] = " "
    fields['.'] = "."
    return template % fields

def _split(field):
    p = field.index(':')
    return field[:p], field[p+1:]

def main(logfifo):
    logfp = open(logfifo)
    while True:
        logline = logfp.readline().strip()
        try:
            fields = dict(map(_split,logline.split(';')))
            print _format(fields)
        except Exception, e:
            print logline

if __name__ == '__main__':
    import sys
    main(*sys.argv[1:])
