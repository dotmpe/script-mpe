#!/usr/bin/env python
"""
:created: 2015-12-27


Usage:
    gcal [options] list-upcoming [<num> [<calId> [<timeargs>...]]]
    gcal [options] [list]
    gcal [options] happening-now <calId> <before> <after>
    gcal [options] delete-calendar <calId>
    gcal [options] insert-calendar <kwargs>...

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -S --secret CLIENT_SECRET_FILE
                JSON formatted credentials.
  --help
                Show help
  --version
                Show version
"""
"""
FIXME: gcal auth
from tools.argparser for argparse.ArgumentParser
gcal.py [-h] [--auth_host_name AUTH_HOST_NAME]
[--noauth_local_webserver]
[--auth_host_port [AUTH_HOST_PORT [AUTH_HOST_PORT...]]]
[--logging_level {DEBUG,INFO,WARNING,ERROR,CRITICAL}]
"""
from __future__ import print_function
import httplib2
import os
from pprint import pprint, pformat

from apiclient import discovery
import oauth2client
from oauth2client import client
from oauth2client import tools

import datetime
from datetime import timedelta
from datetime import datetime

from script_mpe import libcmd_docopt
import confparse


#import argparse
#flags = argparse.ArgumentParser(parents=[tools.argparser]).parse_args()
flags = confparse.Values(dict(
        logging_level= 'INFO',
        noauth_local_webserver= False
    ))


#SCOPES = 'https://www.googleapis.com/auth/calendar.readonly'
SCOPES = 'https://www.googleapis.com/auth/calendar'

# XXX: cleanup
#CLIENT_SECRET_FILE = 'client_secret.json'
#CLIENT_SECRET_FILE = os.getenv('GSPREAD_CREDS_JSON')

CRED_FILE = os.path.expanduser('~/.credentials/script-gcal.json')
CRED_FILE = "/usr/local/lib/python2.7/site-packages/gtasks/credentials.json"
CRED_FILE = "/Users/berend/.local/etc/simza-script-d2efacfe6f41.json"
if not os.path.exists(CRED_FILE):
    raise Exception("Missing CRED_FILE=%r" % CRED_FILE)


APPLICATION_NAME = 'Google Calendar API Python Quickstart'


def get_credentials(app_name, secret_file, credential_path, scopes):
    """Gets valid user credentials from storage.

    If nothing has been stored, or if the stored credentials are invalid,
    the OAuth2 flow is completed to obtain the new credentials.

    Returns:
        Credentials, the obtained credential.
    """

    store = oauth2client.file.Storage(credential_path)
    credentials = store.get()
    if not credentials or credentials.invalid:
        flow = client.flow_from_clientsecrets(secret_file, scopes)
        flow.user_agent = app_name
        #credentials = tools.run(flow, store)
        credentials = tools.run_flow(flow, store, flags)
        print('Storing credentials to ' + credential_path)
    return credentials

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

def H_list(service, opts):
    r = service.calendarList().list().execute()

    for i in r['items']:
        id = i['id']
        print(id, pformat(service.calendarList().get(calendarId=id).execute()))


def H_insert_calendar(service, opts):

    # XXX: read args to json
    kwds = dict([ k.split('=') for k in opts.args.kwargs ])
    for k,v in kwds.items():
        if v == 'true':
            kwds[k] = True
        elif v == 'false':
            kwds[k] = False
        elif v.isdigit():
            kwds[k] = int(v)

    print(service.calendars().insert(body=kwds).execute())

def H_delete_calendar(service, opts):
    print(service.calendars().delete(calendarId=opts.args.calId).execute())


def H_happening_now(service, opts):

    if not opts.args.calId:
        opts.args.calId = 'primary'
    if not opts.args.num:
        opts.args.num = 10

    earlier = timedelta(**kwargs(opts.args.before or 'hours=1'))
    later = timedelta(**kwargs(opts.args.after or 'hours=1'))

    eventsResult = service.events().list(
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


def H_list_upcoming(service, opts):

    if not opts.args.calId:
        opts.args.calId = 'primary'
    if not opts.args.num:
        opts.args.num = 10

    tdargs = tdkwargs(*opts.args.timeargs)

    now = datetime.utcnow().isoformat() + 'Z' # 'Z' indicates UTC time
    later = ( datetime.utcnow() + timedelta(**tdargs) ).isoformat() + 'Z'
    print(now, later)

    eventsResult = service.events().list(
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


handlers = {}
for k, h in locals().items():
    if not k.startswith('H_'):
        continue
    handlers[k[2:].replace('_', '-')] = h


def main(func=None, opts=None):
    """Shows basic usage of the Google Calendar API.
    """
    credentials = get_credentials(APPLICATION_NAME, opts.flags.secret,
            CRED_FILE, SCOPES)
    http = credentials.authorize(httplib2.Http())
    service = discovery.build('calendar', 'v3', http=http)

    return handlers[func](service, opts)



if __name__ == '__main__':
    import sys
    opts = libcmd_docopt.get_opts(__doc__)
    if not opts.cmds:
        opts.cmds = ['list']
    #if not opts.flags.secret:
    #    if 'GCAL_JSON_SECRET_FILE' in os.environ:
    #        opts.flags.secret = os.environ['GCAL_JSON_SECRET_FILE']
    #    else:
    #        opts.flags.secret = CLIENT_SECRET_FILE
    sys.exit( main( opts.cmds[0], opts ) )
