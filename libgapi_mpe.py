# Created: 2020-07-30
from __future__ import print_function
import io
import os
import pickle
import shutil
import sys

from googleapiclient import discovery
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.http import MediaIoBaseDownload
import gspread

from script_mpe import confparse, log
from script_mpe.res import js


def load_secrets(pickle_file):
    if os.path.exists(pickle_file):
        with open(pickle_file, 'rb') as token:
            return pickle.load(token)
    return None

def get_credentials(app_name, client_secret_file, client_token_file, scopes):

    """Gets valid user credentials from storage.

    If nothing has been stored, or if the stored credentials are invalid,
    the OAuth2 flow is completed to obtain the new credentials.

    Returns:
        google.oauth2.credentials.Credentials instance
    """

    credentials = load_secrets(client_token_file)

    if not credentials or not credentials.valid:
        if credentials and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                    client_secret_file, scopes)
            credentials = flow.run_local_server(port=0)

        with open(client_token_file, 'wb') as token:
            pickle.dump(credentials, token)

    return credentials

google_apiversion = dict(
    sheets='v4',
    drive='v3',
    calendar='v3',
    blogger='v3',
    books='v1',
    tasks='v1'
  )

def get_services(settings, *keys):
    if not hasattr(settings, 'services'):
        settings.services = confparse.Values()
    if settings.credentials and settings.credentials.valid:
        for k in keys:
            service = discovery.build(k, google_apiversion[k],
                    credentials=settings.credentials)
            setattr(settings.services, k, service)

def gdrive_list(service, settings, parent_id=None, media_type=None,
        next_page=None, include_folders=False, order_by=None,
        spaces=None):
    """
    NOTE: access to other spaces is probably limited by ownership, none
    of the other spaces list anything.
    Not sure if we can do anything about the permissions for app or photo
    files.
    """
    q="trashed = false"
    if media_type:
        q+=" and mimeType='{}'".format(media_type)
    if parent_id:
        q+=" and parents in '{}'".format(parent_id)
    if not order_by:
        order_by='createdTime desc'
    if not include_folders:
        q+=" and mimeType!='application/vnd.google-apps.folder'"
    if not spaces: spaces = 'drive'
    rs = service.files().list(
        pageToken=next_page,
        pageSize=settings.pagesize,
        fields="nextPageToken, files(id, name, parents, mimeType)",
        orderBy=order_by,
        q=q,
        spaces=spaces
      ).execute()
    files = rs.get('files', [])
    # Page through results:
    if 'nextPageToken' in rs and settings.all:
        print("fetching next page (%i items)" % ( settings.pagesize ),
                file=sys.stderr)
        files.extend( gdrive_list(service, settings, parent_id, media_type,
            rs['nextPageToken'] ))
    return files

def gdrive_fileinfo_by_name(name, drive):
    assert name
    rs = drive.files().list(
            q="name='%s'" % name,
            fields="files( id, name, parents, mimeType )",
        ).execute()
    if len(rs['files']) == 0:
        raise Exception("No results for '%s'" % name)
    return rs['files'][0]

def gdrive_permissions(ID, drive):
    assert ID
    rs = drive.permissions().list(
            fileId=ID,
            fields="*",
            pageSize=100 # Maximum
        ).execute()
    return rs

def gdrive_download(request):
    fh = io.BytesIO()
    downloader = MediaIoBaseDownload(fh, request)
    done = False
    while done is False:
        status, done = downloader.next_chunk()
        print("Download %d%%." % int(status.progress() * 100))
    return fh

def gdrive_export(drive, ID, FILE, MEDIA_TYPE):
    request = drive.files().export_media(fileId=ID, mimeType=MEDIA_TYPE)
    fh = gdrive_download(request)
    gdrive_safe_file(FILE, fh)

def gdrive_safe_file(filename, bio):
    bl = bio.tell()
    bio.seek(0)
    with open(filename, 'wb') as f:
        shutil.copyfileobj(bio, f, length=bl)

def gdrive_print_result(item, g):
    if 'parents' in item:
        print('{}\t#{}\t{}\t#{}'.format(item['name'], item['id'],
            item['mimeType'], '# '.join(item['parents'])))
    else:
        print('{}\t#{}\t{}\t'.format(item['name'], item['id'],
            item['mimeType']))

def gdrive_print_results(item, g):
    print('# Name, Id, MIME, parents')

def gdrive_name_to_id(title_or_id, drive):
    if not title_or_id: return
    if title_or_id.startswith('key:'):
        file_id = title_or_id[4:]
    elif title_or_id.startswith('#'):
        file_id = title_or_id[1:]
    else:
        file_id = gdrive_fileinfo_by_name(title_or_id, drive)['id']
    return file_id

def clean_id_arg(file_id, fail=False):
    if not file_id: return
    if file_id.startswith('key:'):
        return file_id[4:]
    elif file_id.startswith('#'):
        return file_id[1:]
    elif not fail:
        return file_id
    return False

def cmd_login(credentials, g, opts):
    """
    Validate credentials, or go through authorization workflow to get valid
    credentials.

    Examples:
        login           # Run login flow if required
        login --valid   # Check only for valid cached credentials
        login --force   # Delete cached and re-login (for changing scopes)
    """
    if g.valid:
        credentials = load_secrets(opts.flags.token)
        return credentials and credentials.valid

    if g.force:
        if os.path.exists(opts.flags.token):
            os.unlink(opts.flags.token)

    cmd_mod = sys.modules['__main__']
    app_name = cmd_mod.__description__
    credentials = get_credentials(app_name,
            opts.flags.secret,
            opts.flags.token,
            cmd_mod.SCOPES)
    log.stderr("{green}OK{default}. Logged in")

command_handlers = dict(
    login = cmd_login
)

def cmd_count_all(g, PARENT_ID=None):
    PARENT_ID = clean_id_arg(PARENT_ID)
    print(len(list(g.services.drive, g, PARENT_ID)))

def cmd_list_all(g, PARENT_ID=None):
    PARENT_ID = clean_id_arg(PARENT_ID)
    files = list(g.services.drive, g, PARENT_ID)
    print('# Name, Id, MIME, parents')
    for file in files:
        if 'parents' in folder:
            print('{}\t#{}\t{}\t#{}'.format(file['name'], file['id'],
                file['mimeType'], '# '.join(file['parents'])))
        else:
            print('{}\t#{}\t{}\t'.format(file['name'], file['id'],
                file['mimeType']))

def cmd_count_folders(g, PARENT_ID=None):
    PARENT_ID = clean_id_arg(PARENT_ID)
    print(len(gdrive_list(g.services.drive, g, PARENT_ID,
            'application/vnd.google-apps.folder')))

def cmd_list_folders(g, PARENT_ID=None):
    PARENT_ID = clean_id_arg(PARENT_ID)
    folders = gdrive_list(g.services.drive, g, PARENT_ID,
            'application/vnd.google-apps.folder')
    for folder in folders:
        if 'parents' in folder:
            print('{}\t#{}\t#{}'.format(folder['name'], folder['id'],
                    ' '.join(folder['parents'])))
        else:
            print('{}\t#{}\t'.format(folder['name'], folder['id']))

def cmd_count_spreadsheets(g, PARENT_ID=None):
    PARENT_ID = clean_id_arg(PARENT_ID)
    print(len(gdrive_list(g.services.drive, g, PARENT_ID,
            'application/vnd.google-apps.spreadsheet')))

def cmd_list_spreadsheets(g, PARENT_ID=None):
    PARENT_ID = clean_id_arg(PARENT_ID)
    sheets = gdrive_list(g.services.drive, g, PARENT_ID,
            'application/vnd.google-apps.spreadsheet')
    for sheet in sheets:
        print('{}\t#{}'.format(sheet['name'], sheet['id']))

gdrive_command_handlers = {
    'count-all':  cmd_count_all,
    'list-all':  cmd_list_all,
    'count-folders':  cmd_count_folders,
    'list-folders':  cmd_list_folders,
    'count-spreadsheets':  cmd_count_spreadsheets,
    'list-spreadsheets':  cmd_list_spreadsheets,
}


def gspread_export(TITLE_OR_ID, SHEET, FILE, services, g):
    ID = gdrive_name_to_id(TITLE_OR_ID, services.drive)
    gc = gspread.service_account()
    book = gc.open_by_key(ID)
    if FILE: of = ext_output_formats[FILE[-3:]]
    else: of = g.output_format
    if SHEET:
        sheet_export[of](book.worksheet(SHEET), g)
    else:
        sheet_export[of](book, g)


def sheet_csv(book, g):
    if g.sheet:
        sheet = book.get_worksheet(g.sheet)
        for row in sheet.get_all_values():
            print(','.join(row))
    elif hasattr(book, 'worksheets'):
        for sheet in book.worksheets():
            for row in sheet.get_all_values():
                print(','.join(row))
            print('\f')
    else:
        for row in book.get_all_values():
            print(','.join(row))

def sheet_tsv(book, g):
    if g.sheet:
        sheet = book.get_worksheet(g.sheet)
        for row in sheet.get_all_values():
            print('\t'.join(row))
    elif hasattr(book, 'worksheets'):
        for sheet in book.worksheets():
            for row in sheet.get_all_values():
                print('\t'.join(row))
            print('\f')
    else:
        for row in book.get_all_values():
            print('\t'.join(row))

def sheet_json(book, g):
    kwds = {}
    if g.pretty: kwds['indent']=2
    if g.sheet:
        sheet = book.get_worksheet(g.sheet)
        if g.bare:
            print(js.dumps(sheet.get_all_values(), **kwds))
        else:
            print(js.dumps({
                'title': sheet.title,
                'values': sheet.get_all_values()
            }, **kwds))
    elif hasattr(book, 'worksheets'):
        sheets = []
        for sheet in book.worksheets():
            if g.bare:
                sheets.append({
                    'title': sheet.title,
                    'values': sheet.get_all_values()
                })
            else:
                sheets.append(sheet.get_all_values())
        if g.bare:
            print(js.dumps([sheets], **kwds))
        else:
            print(js.dumps({
                'title': book.title,
                'sheets': sheets
            }, **kwds))
    else:
        if g.bare:
            print(js.dumps(book.get_all_values(), **kwds))
        else:
            print(js.dumps({
                'title': book.title,
                'values': book.get_all_values()
            }, **kwds))

sheet_export = dict(
    tsv=sheet_tsv,
    csv=sheet_csv,
    json=sheet_json
)

#
