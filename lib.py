"""
:Created: 2011-05-15
"""
from __future__ import print_function
import datetime
import getpass
import optparse
import os
import re
import select
import socket
import subprocess
import sys
import readline
from os.path import basename, join,\
        isdir

#from docutils.nodes import make_id
# Copy from docutils.nodes.make_id and parts (public domain)
import unicodedata
def make_id(string):
    id = string.lower()
    if not isinstance(id, unicode):
        id = id.decode()
    id = id.translate(_non_id_translate_digraphs)
    id = id.translate(_non_id_translate)
    # get rid of non-ascii characters.
    # 'ascii' lowercase to prevent problems with turkish locale.
    id = unicodedata.normalize('NFKD', id).\
         encode('ascii', 'ignore').decode('ascii')
    # shrink runs of whitespace and replace by hyphen
    id = _non_id_chars.sub('-', ' '.join(id.split()))
    id = _non_id_at_ends.sub('', id)
    return str(id)

_non_id_chars = re.compile('[^a-z0-9]+')
_non_id_at_ends = re.compile('^[-0-9]+|-+$')
_non_id_translate = {
    0x00f8: u'o',       # o with stroke
    0x0111: u'd',       # d with stroke
    0x0127: u'h',       # h with stroke
    0x0131: u'i',       # dotless i
    0x0142: u'l',       # l with stroke
    0x0167: u't',       # t with stroke
    0x0180: u'b',       # b with stroke
    0x0183: u'b',       # b with topbar
    0x0188: u'c',       # c with hook
    0x018c: u'd',       # d with topbar
    0x0192: u'f',       # f with hook
    0x0199: u'k',       # k with hook
    0x019a: u'l',       # l with bar
    0x019e: u'n',       # n with long right leg
    0x01a5: u'p',       # p with hook
    0x01ab: u't',       # t with palatal hook
    0x01ad: u't',       # t with hook
    0x01b4: u'y',       # y with hook
    0x01b6: u'z',       # z with stroke
    0x01e5: u'g',       # g with stroke
    0x0225: u'z',       # z with hook
    0x0234: u'l',       # l with curl
    0x0235: u'n',       # n with curl
    0x0236: u't',       # t with curl
    0x0237: u'j',       # dotless j
    0x023c: u'c',       # c with stroke
    0x023f: u's',       # s with swash tail
    0x0240: u'z',       # z with swash tail
    0x0247: u'e',       # e with stroke
    0x0249: u'j',       # j with stroke
    0x024b: u'q',       # q with hook tail
    0x024d: u'r',       # r with stroke
    0x024f: u'y',       # y with stroke
}
_non_id_translate_digraphs = {
    0x00df: u'sz',      # ligature sz
    0x00e6: u'ae',      # ae
    0x0153: u'oe',      # ligature oe
    0x0238: u'db',      # db digraph
    0x0239: u'qp',      # qp digraph
}

from script_mpe import log
#import confparse
#
#
#config = confparse.expand_config_path('cllct.rc')
#"Configuration filename."
#
#settings = confparse.load_path(*config)
#"Static, persisted settings."

hostname = socket.gethostname()
username = getpass.getuser()


RSR_NS = 'rsr', 'http://name.wtwta.nl/#/rsr'

# Util functions

rcs_path = re.compile('^.*\/\.(svn|git|bzr|hg)$')

def is_scmdir(dirpath):
    assert isdir(dirpath), dirpath
    for d in os.listdir(dirpath):
        p = join(dirpath, d)
        m = rcs_path.match(p)
        if m:
            return True

def cmd(cmd, cwd=None, allowempty=False, allowerrors=False, allow=[]):
    "Simple wrapper for subprocess.Popen"
    if isinstance(cmd, basestring):
        cmd = [ cmd ]
    assert isinstance(cmd, list)
    proc = subprocess.Popen( cmd ,
            shell=True,
            stderr=subprocess.PIPE,
            stdout=subprocess.PIPE,
            close_fds=True, cwd=cwd )
    errors = None
    if not allowerrors:
        errors = proc.stderr.read()
    if errors or (
        proc.returncode and proc.returncode not in allow
    ):
        raise Exception(errors or "subproc returned %i" % proc.returncode)
    value = proc.stdout.read()
    if not value and not allowempty:
        raise Exception("subproc %r returned nothing" % cmd)
    return value

def get_checksum_sub(path, checksum_name='sha1'):
    """
    Utitilize OS <checksum_name>sum command which is likely more
    efficient than reading in files in native Python.

    Returns the hexadecimal encoded digest directly.
    """
    pathd = path.decode('utf-8')
    data = cmd("%ssum \"%s\"", checksum_name, pathd)
    p = data.index(' ')
    hex_checksum, filename = data[:p], data[p:].strip()
    # XXX: sanity check..
    assert filename == path, (filename, path)
    return hex_checksum

def get_sha1sum_sub(path):
    return get_checksum_sub(path)

def get_md5sum_sub(path):
    return get_checksum_sub(path, 'md5')

def get_format_description_sub(path):
    format_descr = cmd("file -bs %r", path).strip()
    return format_descr

uname = cmd("uname -s").strip()
def get_mediatype_sub(path):
    if uname == 'Linux':
        try:
            mediatypespec = cmd(["xdg-mime query filetype %r" % path]).strip()
        except Exception as e:
            mediatypespec = cmd(["file -bsi %r" % path]).strip()
    elif uname == 'Darwin':
        mediatypespec = cmd(["file -bsI %r" % path]).strip()
    else:
        mediatypespec = cmd(["file -bsi %r" % path]).strip()
        assert not True, uname

    return mediatypespec

def remote_proc(host, cmd):
    proc = subprocess.Popen(
        'ssh '+ username+'@'+host + " '%s'" % cmd,
            shell=True,
            stderr=subprocess.PIPE, stdout=subprocess.PIPE,
            close_fds=True
        )
    errresp = proc.stderr.read()
    if errresp:
        errresp = "Error: "+ errresp.replace('ssh: ', host).strip()
        raise Exception(errresp)
    else:
        return proc.stdout.read().strip()

def human_readable_float(value, suffix=True, suffix_as_separator=False,
        sub=2):
    if suffix_as_separator:
        assert suffix
    fmt = "%%.%if" % sub

    order = 1024
    if value < order:
        return str(value)
    else:
        order *= 1024
        if value < order:
            fmt += 'K'
        else:
            order *= 1024
            if value < order:
                fmt += 'M'
            else:
                order *= 1024
                if value < order:
                    fmt += 'G'
                else:
                    order *= 1024
                    if value < order:
                        fmt += 'T'
                    else:
                        order *= 1024
                        if value < order:
                            fmt += 'P'
                        else:
                            order *= 1024
                            if value < order:
                                fmt += 'E'
                            else:
                                order *= 1024
                                if value < order:
                                    fmt += 'Z'
                                else:
                                    order *= 1024
                                    if value < order:
                                        fmt += 'Y'
                                    else:
                                        raise Exception('unit overflow')

    s = fmt % (float(value)/(order/1024))
    if suffix_as_separator and not s[-1].isdigit():
        s = s[:-1].replace('.', s[-1])
    return s

# The epoch used in the datetime API.
EPOCH = datetime.datetime.utcfromtimestamp(0)


def timedelta_to_seconds(delta):
    seconds = (delta.microseconds * 1e6) + delta.seconds + (delta.days * 86400)
    seconds = abs(seconds)

    return seconds

def datetime_to_timestamp(date, epoch=EPOCH):
    # Ensure we deal with `datetime`s.
    #date = datetime.datetime.utcfromtimestamp(date)
    epoch = datetime.datetime.utcfromtimestamp(epoch.toordinal())

    timedelta = date - epoch
    timestamp = timedelta_to_seconds(timedelta)

    return timestamp

def timestamp_to_datetime(timestamp, epoch=EPOCH):
    # Ensure we deal with a `datetime`.
    epoch = datetime.datetime.utcfromtimestamp(epoch.toordinal())

    epoch_difference = timedelta_to_seconds(epoch - EPOCH)
    adjusted_timestamp = timestamp - epoch_difference

    date = datetime.datetime.utcfromtimestamp(adjusted_timestamp)

    return date


def class_name(o):
#    if hasattr(o, __class__):
#        o = o.__class__
    return o.__class__.__name__

cn = class_name


def tag_id(s):
    if not s.strip():
        return
    if s[0].isdigit():
        s = 'n-%s' % s
    return make_id(s)

if __name__ == '__main__':
    print(get_sha1sum_sub("volume.py"));

    for f in sys.argv:
        if not os.path.exists(f):
            continue
        for n, ts in (
                ('c',os.path.getctime(f)),
                ('a',os.path.getatime(f)),
                ('m',os.path.getmtime(f)),):
            print(n, timestamp_to_datetime(ts), f)



# http://code.activestate.com/recipes/134892-getch-like-unbuffered-character-reading-from-stdin/
class _Getch:
    """Gets a single character from standard input.  Does not echo to the
screen."""
    def __init__(self):
        try:
            self.impl = _GetchWindows()
        except ImportError:
            self.impl = _GetchUnix()

    def __call__(self): return self.impl()

class _GetchUnix:
    def __init__(self):
        import tty, sys

    def __call__(self):
        import sys, tty, termios
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(sys.stdin.fileno())
            ch = sys.stdin.read(1)
            if ch == '\x03':
                raise KeyboardInterrupt
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch

class _GetchWindows:
    def __init__(self):
        import msvcrt

    def __call__(self):
        import msvcrt
        return msvcrt.getch()

getch = _Getch()

class Prompt(object):

    """
    Static interactive templates for readline user-interaction.
    """

    @classmethod
    def ask(klass, question, yes_no='Yn'):
        assert len(yes_no) == 2, "Need two choices, a logica true and false, but options don't match: %r" % yes_no
        yes, no = list(yes_no)
        assert yes.isupper() or no.isupper()
        #v = raw_input('%s [%s] ' % (question, yes_no))
        print('%s [%s] ' % (question, yes_no))
        v = getch().strip()
        if not v:
            if yes.isupper():
                v = yes
            else:
                v = no
        elif v.upper() not in yes_no.upper():
            return
        return v.upper() == yes.upper()

    @classmethod
    def raw_input(klass, prompt, default=None):
        v = input('%s [%s] ' % (prompt, default))
        if v:
            return v
        elif default:
            return default

    @staticmethod
    def input(prompt, prefill=''):
        """
        FIXME: this does not work on Darwin, even with brew readline-6.2.4?
        """
        readline.set_startup_hook(lambda: readline.insert_text(prefill))
        try:
            return input(prompt)
        finally:
            readline.set_startup_hook()

    @staticmethod
    def create_choice(options):
        "Options must be list of strings, one capitalized unique character each"
        opts = ''
        for i, o in enumerate(options):
            for c in o:
                if c.istitle():
                    assert c not in opts, c
                    opts += c
                    options[i] = o.replace(c, "{white}%s{blue}" % c)
        return opts

    @classmethod
    def query(klass, question, options=[]):
        """
            Prompt.query( "What shall it be?", [ "Nothing", "Everything", "eLse" ] )
        """
        assert options
        options = list(options)
        origopts = list(options)
        opts = klass.create_choice(options)
        while True:
            print(log.format_str('{green}%s {blue}%s {bwhite}[{white}%s{bwhite}]{default} or [?help] ' %
                    (question, ','.join(options), opts)))
#            v = sys.stdin.read(1)
            v = getch()
            #v = raw_input(
            #        log.format_str('{green}%s {bwhite}[{bblack}%s{bwhite}]{default} or [?help] ')
            #        % (question, opts)).strip()
            if not v.strip(): # FIXME: have to only strip whitespace, not ctl?
                v = opts[0]
            if v == 'help'  or v in '?h':
                print(log.format_str(("{default}Choose from %s{default}. Default is %r{default}, use --recurse option to override. ") % (', '.join(options), options[0])))
            if v.upper() in opts.upper():
                choice = opts.upper().index(v.upper())
                print('Answer:', origopts[choice].title())
                return choice

    @classmethod
    def pick(klass, question, items=[], num=False):
        if not question:
            question = "Select one"
        instruction = "enter choice (1-%i) and press return" % (len(items))
        while True:
            print(log.format_str('{green}%s {blue}\n%s\n{bwhite}[{white}%s{bwhite}]{default} ' %
                    (question,  "\n".join([ "%i. %s" %(i+1, v) for i,v in
                        enumerate(items)]), instruction)))
            v = ''
            while True:
                x = getch()
                if x == '\r': # Return
                    break
                if x == '\x7f': # Backspace
                    print('\r%s\r'%''.rjust(len(v)),end='')
                    v = v[:-1]
                    print(v,end='')
                    continue
                if not x.strip() or not x.isdigit():
                    v = '' ; print('\r',end=''); break
                v += x
                print(x,end='')
            if not v: continue
            print()
            i = int(v)
            if i > len(items):
                continue
            if num:
                return i-1
            return items[i-1]
