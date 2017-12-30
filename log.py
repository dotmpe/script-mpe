#!/bin/env python
#
# An output colorizer for syslog.
#
from __future__ import print_function
import sys
import os
import re


class ScriptOut(object):

    def __init__(self):
        super(ScriptOut, self).__init__()
        self.init()

    def init(self):
        import confparse
        # TODO: cleanup global state for script logging
        self.settings = confparse.Values(dict(
                cs = os.getenv('CS', 'dark'),
                category = 4,
                #category = 7,
                strict = False,
                formatting_enabled = True,
            ))

    def format_args(self, args):
        "Stringify any non-builtins"
        args = list(args)
        for i, a in enumerate(args):
            type_ = type(a)
            if type_ == getattr( __builtin__, type_.__name__ ):
                pass
            else:
                args[i] = str(a)
        return args

category = 4
strict = False
formatting_enabled = True

# global for scripts that don't do their own logging/output config
out = ScriptOut()


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
palette2 = {}
palette2.update(locals())

format = "c04,TS,c16,PRI,c05,HOSTNAME,c17,msg,c00"
error1 = "c00,TS,c10,PRI,c05,HOSTNAME,c11,msg,c00"

level_templates = {
    'emerg':  "c11,TS,c05, ,HOSTNAME, ,FAC,.,c11,LVL, ,c01,msg,c00",
    'alert':  "c13,TS,c05, ,HOSTNAME, ,FAC,.,c11,LVL, ,c07,msg,c00",
#    'crit':   "c13,TS,c05, ,HOSTNAME, ,FAC,.,c11,LVL, ,c07,msg,c00",
    'crit':   "TS, ,HOSTNAME, ,FAC,.,LVL, ,msg",
    'err':    "c03,TS,c05, ,HOSTNAME, ,FAC,.,c01,LVL, ,c07,msg,c00",
    'warn':   "c03,TS,c05, ,HOSTNAME, ,FAC,.,c03,LVL, ,c07,msg,c00",
    'notice': "c07,TS,c05, ,HOSTNAME, ,FAC,.,c07,LVL, ,c07,msg,c00",
    'info':   "c07,TS,c05, ,HOSTNAME, ,FAC,.,c10,LVL, ,c07,msg,c00",
    'debug':  "c08,TS,c05, ,HOSTNAME, ,FAC,.,c10,LVL, ,c10,msg,c00",
}

def _format(fields):
#    return "; ".join(map(":".join,fields.items()))
    facility, level = fields['PRI-text'].split('<')[0].split('.')
    fields['FAC'] = facility
    fields['LVL'] = level
    template = "".join(map(
            "%%(%s)s".__mod__,
            level_templates[level].split(",")
        ))
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
            print(_format(fields))
        except Exception as e:
            print(logline)

# xxx: new logger code may 2012
# syslog compat. levels
EMERG, ALERT, CRIT, ERR, WARN, NOTE, INFO, DEBUG = range(0,8)
#CHATTER = 1
NAMES = ( 'EMERG', 'ALERT', 'CRIT', 'ERR', 'WARN', 'NOTE', 'INFO', 'DEBUG' )

palette = dict(
    default='\x1b[0;0m', # default
    black='\x1b[0;30m', # black/d-gray
    bblack='\x1b[1;30m', # bold black/d-gray
    red='\x1b[0;31m', # red
    bred='\x1b[1;31m', #
    green='\x1b[0;32m', # green
    bgreen='\x1b[1;32m', # green
    yellow='\x1b[0;33m', # orange
    byellow='\x1b[1;33m', # yellow/orange
    blue='\x1b[0;34m', # blue
    bblue='\x1b[1;34m', # blue
    magenta='\x1b[0;35m', # magenta
    bmagenta='\x1b[1;35m',
    cyan='\x1b[0;36m', # cyan
    bcyan='\x1b[1;36m',
    white='\x1b[0;37m', # white/l-gray
    bwhite='\x1b[1;37m', # bright white
)

def format_str(msg):
    for k in palette:
        msg = msg.replace('{%s}' % k, palette[k])
    return msg

def stdout(msg, *args):
    global formatting_enabled
    if not formatting_enabled:
        msg = re.sub(r'\{[a-z]+\}', '', msg)
    if args:
        print(format_str(msg % args))
    else:
        print(format_str(msg))

std = stdout

def stderr(msg, *args):
    global formatting_enabled
    if not formatting_enabled:
        msg = re.sub(r'\{[a-z]+\}', '', msg)
    if args:
        print(format_str(msg % args), file=sys.stderr)
    else:
        print(format_str(msg))


def log(level, msg, *args):
    """
    TODO:
  0. Emergency (emerg), system is unusable.
  1. Alert, immeadeate action required.
  2. Critical (crit).
  3. Error (err).
  4. Warning (warn).
  5. Notice (note).
  6. Informational (info).
  7. Debug.
    """
    assert isinstance(level, int)
    global out, category, formatting_enabled
    g = out.settings

    if not isinstance(msg, (basestring, int, float)):
        msg = str(msg)
    title = {
            0:'{bred}Emergency{bwhite}',
            1:'{red}Alert{white}',
            2:'{red}Critical{white}',
            3:'{byellow}Error{default}',
            4:'{yellow}warning{default}',
            5:'{green}Note{default}',
            6:'{bblack}info{default}',
            7:'{bwhite}Debug{default}'
        }
    if strict:
        if level != category:
            return
    else:
        if level > category:
            return
    if level in title:
        msg = title[level] +': '+ msg
    if formatting_enabled:
        msg = format_str(msg + '{default}')
    else:
        msg = re.sub(r'\{[a-z]+\}', '', msg)

    # Turn everything into primitives for str-formatting; num bool & str/uni.
    args = out.format_args(args)

    print(msg % tuple(args), file=sys.stderr)

emerg = lambda x,*y: log(EMERG, x, *y)
alert = lambda x,*y: log(ALERT, x, *y)
crit =  lambda x,*y: log(CRIT,  x, *y)
err =   lambda x,*y: log(ERR,   x, *y)
warn =  lambda x,*y: log(WARN,  x, *y)
note =  lambda x,*y: log(NOTE,  x, *y)
info =  lambda x,*y: log(INFO,  x, *y)
debug = lambda x,*y: log(DEBUG, x, *y)

def test():

    log(EMERG, "Test test {green}test{default}")
    log(ALERT, "Test test {green}test{default}")
    log(CRIT, "Test test {green}test{default}")
    log(ERR, "Test test {green}test{default}")
    log(WARN, "Test test {green}test{default}")
    log(NOTE, "Test test {green}test{default}")
    log(INFO, "Test test {green}test{default}")
    log(DEBUG, "Test test {green}test{default}")


if __name__ == '__main__':
    import sys
    from script_mpe.taxus import out
    test()
