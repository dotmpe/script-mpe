#!/usr/bin/env python
# Created: 2015-12-27
# Updated: 2020-07-30
from __future__ import print_function
__description__ = 'x-gcal Google Calendar API Python CLI'
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Experimental Google Calendar

Usage:
    gcal [options] list-upcoming [<num> [<calId> [<timeargs>...]]]
    gcal [options] [list]
    gcal [options] happening-now <calId> <before> <after>
    gcal [options] delete-calendar <calId>
    gcal [options] insert-calendar <kwargs>...
    gcal [options] login [--valid]
    gcal help | --help
    gcal --version

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -S, --secret CLIENT_ID_FILE
                JSON formatted client secret (credentials).
  -T, --token CLIENT_TOKEN_FILE
                Pickled client token (validated credentials).
  --print-memory
                Print memory usage just before program ends.

"""
import os
from pprint import pprint, pformat

import datetime
from datetime import timedelta
from datetime import datetime

from script_mpe import libcmd_docopt, libgapi_mpe
import confparse


CLIENT_ID_FILE = os.path.expanduser('~/.local/etc/token.d/google/x-script-mpe/credentials.json')
CLIENT_TOKEN_FILE = os.path.expanduser('~/.local/etc/token.d/google/x-script-mpe/credentials-gcal.pickle')

SCOPES_RO = ['https://www.googleapis.com/auth/calendar.readonly']
SCOPES = ['https://www.googleapis.com/auth/calendar']


def gcal_defaults(opts, init={}):
    libcmd_docopt.defaults(opts)

    if not opts.cmds:
        opts.cmds = ['list']

    if not opts.flags.secret:
        if 'GCAL_JSON_CLIENT_ID_FILE' in os.environ:
            opts.flags.secret = os.environ['GCAL_JSON_CLIENT_ID_FILE']
        else:
            opts.flags.secret = CLIENT_ID_FILE

    if not opts.flags.token:
        if 'GCAL_TOKEN_FILE' in os.environ:
            opts.flags.token = os.environ['GCAL_TOKEN_FILE']
        else:
            opts.flags.token = CLIENT_TOKEN_FILE

    return init

def kwargs(*args):
    kwds = dict([ k.split('=') for k in args ])
    for k,v in kwds.items():
        if v.isdigit():
            kwds[k] = int(v)
    return kwds

def tdkwargs(*args):
    kwds = kwargs(*args)
    if not kwds:
        kwds['days'] = 1
    return kwds

def td2dt(timedelta, time=datetime.utcnow()):

    return (time + timedelta).isoformat() + 'Z'


## Sub-cmd handlers

def cmd_list(g, opts):
    r = g.services.calendar.calendarList().list().execute()

    service = g.services.calendar
    for i in r['items']:
        id = i['id']
        print(id, pformat(service.calendarList().get(calendarId=id).execute()))


def cmd_insert_calendar(g, opts):

    # XXX: read args to json
    kwds = dict([ k.split('=') for k in opts.args.kwargs ])
    for k,v in kwds.items():
        if v == 'true':
            kwds[k] = True
        elif v == 'false':
            kwds[k] = False
        elif v.isdigit():
            kwds[k] = int(v)

    print(g.services.calendar.calendars().insert(body=kwds).execute())

def cmd_delete_calendar(g, opts):
    print(g.services.calendar.calendars().delete(calendarId=opts.args.calId).execute())


def cmd_happening_now(g, opts):

    if not opts.args.calId:
        opts.args.calId = 'primary'
    if not opts.args.num:
        opts.args.num = 10

    earlier = timedelta(**kwargs(opts.args.before or 'hours=1'))
    later = timedelta(**kwargs(opts.args.after or 'hours=1'))

    eventsResult = g.services.calendar.events().list(
        calendarId=opts.args.calId,
        timeMin=td2dt(earlier),
        timeMax=td2dt(later),
        maxResults=opts.args.num,
        singleEvents=True,
        orderBy='startTime').execute()
    events = eventsResult.get('items', [])

    if not events:
        return 1
    for event in events:
        start = event['start'].get('dateTime', event['start'].get('date'))
        print(start, event['summary'])


def cmd_list_upcoming(g, opts):

    if not opts.args.calId:
        opts.args.calId = 'primary'
    if not opts.args.num:
        opts.args.num = 10

    tdargs = tdkwargs(*opts.args.timeargs)

    now = datetime.utcnow().isoformat() + 'Z' # 'Z' indicates UTC time
    later = ( datetime.utcnow() + timedelta(**tdargs) ).isoformat() + 'Z'
    print(now, later)

    eventsResult = g.services.calendar.events().list(
        calendarId=opts.args.calId,
        timeMin=now, timeMax=later,
        maxResults=opts.args.num,
        singleEvents=True,
        orderBy='startTime').execute()
    events = eventsResult.get('items', [])

    if not events:
        return 1
    for event in events:
        start = event['start'].get('dateTime', event['start'].get('date'))
        print(start, event['summary'])


commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(libcmd_docopt.command_handlers)
commands.update(libgapi_mpe.command_handlers)

def gcal_main(opts):
    g = opts.flags
    g.credentials = libgapi_mpe.load_secrets(opts.flags.token)
    libgapi_mpe.get_services(g, 'calendar')
    ret = libcmd_docopt.run_commands(commands, g, opts)
    if g.print_memory:
        libcmd_docopt.cmd_memdebug(g)
    return ret

def gcal_version():
    return 'x-gcal.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf8')
    opts = libcmd_docopt.get_opts(__description__+'\n'+__usage__,
            version=gcal_version(), defaults=gcal_defaults)
    sys.exit( gcal_main( opts ) )
