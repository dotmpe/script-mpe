#!/usr/bin/env python
# Created: 2020-07-31
from __future__ import print_function
__description__ = 'x-gdrive Google Drive API Python CLI'
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Experimental Google Drive

Usage:
    gdrive [options] list [PARENT_ID] [MEDIA_TYPE]
    gdrive [options] download TITLE_OR_ID [FILE]
    gdrive [options] export TITLE_OR_ID [MEDIA_TYPE] [FILE]
    gdrive [options] info ID [TITLE]
    gdrive [options] delete TITLE_OR_ID
    gdrive [options] ( list-folders | list-spreadsheets ) [PARENT_ID]
    gdrive [options] permissions TITLE_OR_ID
    gdrive [options] authorize TITLE_OR_ID USER [ROLE]
    gdrive [options] login [--force|--valid]
    gdrive [options] about [A]
    gdrive help | --help
    gdrive --version

Options:
  -q, --quiet   Quiet operations
  -s, --strict  Strict operations
  -S, --secret CLIENT_ID_FILE
                JSON formatted client secret (credentials).
  -T, --token CLIENT_TOKEN_FILE
                Pickled client token (validated credentials).
  -n, --pagesize NUM
                Set result-length (1-1000) [Default: 25]
  -a, --all     Fetch all pages
  --spaces SPACES
                Comma-separated spaces (drive, appDataFolder and
                photos) [default: drive]
  --print-memory
                Print memory usage just before program ends.
  --include-folders
                Include folder items when listing.
  -o, --output-format FMT
                Output format for some commands [default: json]

"""

import os

from script_mpe import libcmd_docopt, libgapi_mpe, log
from script_mpe.libgapi_mpe import gdrive_list, gdrive_print_result, \
        clean_id_arg, gdrive_name_to_id
from script_mpe.res import js



CLIENT_ID_FILE = os.path.expanduser('~/.local/etc/token.d/google/api-project/credentials.json')

CLIENT_TOKEN_FILE = os.path.expanduser('~/.local/etc/token.d/google/x-script-mpe/credentials-gdrive.pickle')

SCOPES = ['https://www.googleapis.com/auth/drive',
        'https://www.googleapis.com/auth/drive.appdata',
        'https://www.googleapis.com/auth/drive.photos.readonly' ]


def gdrive_defaults(opts, init={}):
    libcmd_docopt.defaults(opts)

    if not opts.cmds:
        opts.cmds = ['list']

    if not opts.flags.secret:
        if 'GDRIVE_JSON_CLIENT_ID_FILE' in os.environ:
            opts.flags.secret = os.environ['GDRIVE_JSON_CLIENT_ID_FILE']
        else:
            opts.flags.secret = CLIENT_ID_FILE

    if not opts.flags.token:
        if 'GDRIVE_TOKEN_FILE' in os.environ:
            opts.flags.token = os.environ['GDRIVE_TOKEN_FILE']
        else:
            opts.flags.token = CLIENT_TOKEN_FILE

    opts.flags.pagesize = int(opts.flags.pagesize)

    return init


def cmd_list(PARENT_ID, MEDIA_TYPE, g):
    """
    Get one or all pages, sorted by created descending.
    """
    PARENT_ID = clean_id_arg(PARENT_ID)
    files = gdrive_list(g.services.drive, g, parent_id=PARENT_ID,
            media_type=MEDIA_TYPE, include_folders=g.include_folders,
            spaces=g.spaces)
    print('# Name, Id, MIME, parents')
    for file in files:
        gdrive_print_result(file, g)


def cmd_info(ID, TITLE, g):
    """
    Print basic details for one entry, fetch either by Id or name.
    """
    if not ID:
        info = libgapi_mpe.gdrive_fileinfo_by_name(TITLE, g.services.drive)
    else:
        ID = clean_id_arg(ID)
        info = libgapi_mpe.gdrive_fileinfo(ID, g.services.drive)
    print('# Name, Id, MIME, parents')
    gdrive_print_result(info, g)


def cmd_delete(TITLE_OR_ID, service, g):
    ID = gdrive_name_to_id(TITLE_OR_ID, service)
    service.files().delete(fileId=ID).execute()
    print("Deleted file with ID '%s'" % ID)


def cmd_download(TITLE_OR_ID, FILE, service, g):
    """
    Download file with ID or name TITLE to FILE. If no FILE is given, its
    name will be used.
    """
    ID = gdrive_name_to_id(TITLE_OR_ID, service)
    if not FILE:
        FILE = libgapi_mpe.gdrive_fileinfo(ID, service)['name']
    request = service.files().get_media(fileId=ID)
    buffer = libgapi_mpe.gdrive_download(request)
    libgapi_mpe.gdrive_safe_file(FILE, buffer)
    print('Downloaded %s' % FILE)


def cmd_export(TITLE_OR_ID, MEDIA_TYPE, FILE, service, g):
    """
    Export to 'application/pdf' or other supported format.
    """
    ID = gdrive_name_to_id(TITLE_OR_ID, service)
    if not FILE: FILE = 'export.pdf'
    libgapi_mpe.gdrive_export(service, ID, FILE, MEDIA_TYPE)
    print('Downloaded %s' % FILE)


def cmd_permissions(TITLE_OR_ID, service, g):
    ID = gdrive_name_to_id(TITLE_OR_ID, service)
    rs = libgapi_mpe.gdrive_permissions(ID, service)
    print('# Name, Id, E-Mail, Type, Role')
    for p in rs['permissions']:
        print('{}\t#{}\t{}\t{}\t{}'.format(
                p['displayName'],
                p['id'],
                p['emailAddress'],
                p['type'],
                p['role']
            ))


def cmd_authorize(TITLE_OR_ID, USER, ROLE, service, g):
    ID = gdrive_name_to_id(TITLE_OR_ID, service)
    if not ROLE: ROLE = 'writer'
    r = service.permissions().create(
            body={
                'type': 'user',
                'role': ROLE,
                'emailAddress': USER
            },
            fileId=ID,
        ).execute()
    log.stderr('{green}OK{default}. %s:%s permission granted' % (
            r['type'],
            r['role'],
        ))


def cmd_about(A, services, g):
    """
    Give info on quotas or import/export formats.
    """
    if A == 'dev':
        about = services.drive.about().get(fields="*").execute()
        if g.output_format == 'csv':
            print(about.keys())
        else:
            print(js.dumps(about, indent=2))
    elif A == 'quotas':
        if g.output_format == 'csv':
            quotas = services.drive.about().get(fields="storageQuota").execute()['storageQuota']
            keys = quotas.keys()
            print("# %s" % ( ", ".join(keys)))
            print("%s" % ( ", ".join([ quotas[k] for k in keys ])))
        else:
            about = services.drive.about().get(fields="storageQuota,maxUploadSize,maxImportSizes").execute()
            print(js.dumps(about, indent=2))
    else:
        about = services.drive.about().get(fields="importFormats,exportFormats").execute()
        print(js.dumps(about, indent=2))


commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(libcmd_docopt.command_handlers)
commands.update(libgapi_mpe.command_handlers)
commands.update(libgapi_mpe.gdrive_command_handlers)

def gdrive_main(opts):
    g = opts.flags
    g.credentials = libgapi_mpe.load_secrets(opts.flags.token)
    libgapi_mpe.get_services(g, 'drive')
    if g.services: g.service = g.services.drive
    else: log.warn("No services loaded")
    ret = libcmd_docopt.run_commands(commands, g, opts)
    if g.print_memory:
        libcmd_docopt.cmd_memdebug(g)
    return ret

def gdrive_version():
    return 'x-gdrive.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf8')
    opts = libcmd_docopt.get_opts(__description__+'\n'+__usage__,
            version=gdrive_version(), defaults=gdrive_defaults)
    sys.exit( gdrive_main( opts ) )
