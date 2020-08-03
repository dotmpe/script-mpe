#!/usr/bin/env python
# ENV-NAME: gspread-boreas
# Created: 2017-03-03
# Updated: 2020-07-30
from __future__ import print_function
__description__ = 'x-gspread Google Sheets API Python CLI'
__version__ = '0.0.4-dev' # script-mpe
__usage__ = """
Experimental Google Docs Spreadsheet

Usage:
    gspread [options] create TITLE [SHEET_TITLE]
    gspread [options] create-worksheet BOOK [TITLE]
    gspread [options] set-value ID SHEET COLROW VALUE
    gspread [options] import-(csv|tsv|tab|json) ID FILE
    gspread [options] read
    gspread [options] export TITLE_OR_ID [FILE]
    gspread [options] export-json TITLE
    gspread [options] export-sheet TITLE_OR_ID SHEET [FILE]
    gspread [options] ( list | list-folders | list-all ) [ PARENT_ID ]
    gspread [options] ( count | count-folders | count-all ) [ PARENT_ID ]
    gspread [options] ( sheets| list-sheets | worksheets ) BOOK
    gspread [options] all-sheets BOOKS...
    gspread [options] info BOOK [SHEET]
    gspread [options] authorize TITLE_OR_ID USER [ROLE]
    gspread [options] permissions TITLE_OR_ID
    gspread [options] delete TITLE_OR_ID
    gspread [options] login [--force|--valid]
    gspread [options] about
    gspread help | --help
    gspread --version

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
  --create
  --sheet TITLE
  --insert-rows
  --append-rows
  --bare
  -o, --output-format FMT
                Output format for some commands [default: json]
  --pretty
  --print-memory
                Print memory usage just before program ends.
  --separator CHAR
Examples:
    gspread export key:0BmgG6nO_6dprdS1MN3d3MkdPa142WFRrdnRRUWl1UFE out.csv

"""

import confparse
import gspread
import os

from script_mpe import libcmd_docopt, libgapi_mpe, log
from script_mpe.libgapi_mpe import gdrive_list, get_credentials
from script_mpe.res import js



CLIENT_ID_FILE = os.path.expanduser('~/.local/etc/token.d/google/x-script-mpe/credentials.json')
CLIENT_TOKEN_FILE = os.path.expanduser('~/.local/etc/token.d/google/x-script-mpe/credentials-gspread.pickle')

SCOPES = ['https://www.googleapis.com/auth/drive',
        'https://www.googleapis.com/auth/spreadsheets']


def gspread_defaults(opts, init={}):
    libcmd_docopt.defaults(opts)

    if 'separator' not in opts or not opts.separator:
        opts.separator = '\t'
    init.update(sep=opts.separator)

    if not opts.cmds:
        opts.cmds = ['list']

    if not opts.flags.secret:
        if 'GSPREAD_JSON_CLIENT_ID_FILE' in os.environ:
            opts.flags.secret = os.environ['GSPREAD_JSON_CLIENT_ID_FILE']
        else:
            opts.flags.secret = CLIENT_ID_FILE

    if not opts.flags.token:
        if 'GSPREAD_TOKEN_FILE' in os.environ:
            opts.flags.token = os.environ['GSPREAD_TOKEN_FILE']
        else:
            opts.flags.token = CLIENT_TOKEN_FILE

    opts.flags.pagesize = int(opts.flags.pagesize)

    return init


def cmd_create(TITLE, SHEET_TITLE, g):
    """Create spreadsheet workbook with default Sheet1, or create new
    sheet in existing workbook.
    """
    gc = gspread.service_account()
    if SHEET_TITLE:
        book = gc.open(TITLE)
        sheet = book.create_worksheet(SHEET_TITLE)
        print(g.sep.join("{} #{} <{}> {} #{} <{}>".split(' ')).format(
            book.title, book.id, book.url, sheet.title, sheet.id, sheet.url))
    else:
        book = gc.create(TITLE)
        print(g.sep.join("{} #{} <{}>".split(' ')).format(
            book.title, book.id, book.url))

def cmd_create_worksheet(BOOK, TITLE, services, g):
    """Create worksheet, selecting spreadsheet book by title or key by
    'key:' or '#:' prefix.
    """
    gc = gspread.service_account()
    ID = libgapi_mpe.gdrive_name_to_id(BOOK, services.drive)
    book = gc.open_by_key(ID)
    sheet = book.add_worksheet(TITLE, 100, 26) # Rows, cols
    print(g.sep.join("{} #{} <{}> {} #{} <{}>".split(' ')).format(
        book.title, book.id, book.url, sheet.title, sheet.id, sheet.url))

def cmd_create_sheet_(TITLE, service): # XXX: cleanup
    spreadsheet = {
            'properties': {
                'title': 'X-GSpread'
            },
            'sheets': [
                {
                    'properties': {
                        'title': 'First sheet'
                     },
                    'fields': "value",
                    'data': [
                        {
                            #'rowData': [
                            #    "1", "2", "3"
                            #],
                            'rowData': [
                                { 'value': 'row 2 col 1', },
                                { 'value': '2.2' },
                                { 'value': '2.3' }
                            ],
#                            'rowData': [
#                                { 'formattedValue': 'row 3 col 1' },
#                                { 'formattedValue': '3.2' },
#                                { 'formattedValue': '3.3' }
#                            ]
                        }
                    ]
                }
            ]
        }
    spreadsheet = service.spreadsheets().create(body=spreadsheet,
            fields='spreadsheetId').execute()
    print('Created spreadsheet ID: {0}'.format(spreadsheet.get('spreadsheetId')))


def cmd_set_value(TITLE_OR_ID, SHEET, COLROW, VALUE, services):
    """
    Test cell to string value.
    """
    ID = libgapi_mpe.gdrive_name_to_id(TITLE_OR_ID, services.drive)
    gc = gspread.service_account()
    book = gc.open_by_key(ID)
    if g.sheet: sheet = book.get_worksheet(g.sheet)
    else: sheet = book.sheet1
    sheet.update(COLROW, VALUE)


def cmd_import_csv(ID, FILE):
    gc = gspread.service_account()
    gc.import_csv(ID, open(FILE, 'r').read())


def cmd_import_tsv(TITLE_OR_ID, services, g):
    gc = gspread.service_account()
    if g.create:
        book = gc.create(TITLE_OR_ID)
    else:
        ID = libgapi_mpe.gdrive_name_to_id(TITLE_OR_ID, services.drive)
        book = gc.open_by_key(ID)
    if g.sheet: sheet = book.get_worksheet(g.sheet)
    else: sheet = book.sheet1
    if FILE and FILE != '-': fh = open(FILE)
    else: fh = sys.stdin
    values = [ ln.split('\t') for ln in fh.readlines() ]
    if g.insert_rows:
        sheet.insert_rows(values)
    elif g.append_rows:
        sheet.append_rows(values)
    else:
        sheet.delete_rows(1, len(values))
        sheet.insert_rows(values)


def cmd_import_tab(TITLE_OR_ID, services, g):
    gc = gspread.service_account()
    # TODO: fixed width table


def cmd_import_json(TITLE_OR_ID, FILE, services, g):
    """
    Import rows/cols nested-lists into sheet, overwriting existing rows
    unless either insert-rows or append-rows options are specified.

    Example:
        echo '[[1,2,3],[4,5]]' | gspread import-json #ABC45ef --sheet 'Some worksheet' --append-rows -
    """
    gc = gspread.service_account()
    if g.create:
        book = gc.create(TITLE_OR_ID)
    else:
        ID = libgapi_mpe.gdrive_name_to_id(TITLE_OR_ID, services.drive)
        book = gc.open_by_key(ID)
    if g.sheet: sheet = book.get_worksheet(g.sheet)
    else: sheet = book.sheet1
    if FILE and FILE != '-': values = js.load(FILE)
    else: values = js.loads(sys.stdin.read())
    if g.insert_rows:
        sheet.insert_rows(values)
    elif g.append_rows:
        sheet.append_rows(values)
    else:
        sheet.delete_rows(1, len(values))
        sheet.insert_rows(values)


def cmd_delete(TITLE_OR_ID):
    gc = gspread.service_account()
    ID = libgapi_mpe.clean_id_arg(TITLE_OR_ID)
    if not ID:
        ID = gspread.open(TITLE_OR_ID).id
    gc.del_spreadsheet(ID)


def cmd_export_json(TITLE_OR_ID, services, g):
    """
    Write one or all sheets from workbook to JSON file. With bare either a
    double or triple nested list depending on wether one sheet or all
    sheets are output. Without bare option workbook/sheets with envelope
    containing title.
    """
    gc = gspread.service_account()
    ID = libgapi_mpe.gdrive_name_to_id(TITLE_OR_ID, services.drive)
    book = gc.open_by_key(ID)
    sheet_export['json'](book, g)

def cmd_export(TITLE_OR_ID, FILE, services, g):
    libgapi_mpe.gspread_export(TITLE_OR_ID, None, FILE, services, g)

def cmd_export_sheet(TITLE_OR_ID, SHEET, FILE, services, g):
    libgapi_mpe.gspread_export(TITLE_OR_ID, SHEET, FILE, services, g)

def cmd_info(BOOK, SHEET, services, g):
    gc = gspread.service_account()
    ID = libgapi_mpe.gdrive_name_to_id(BOOK, services.drive)
    book = gc.open_by_key(ID)
    if SHEET:
        sheet = book.create_worksheet(SHEET_TITLE)
        print(g.sep.join("{} #{} <{}> {} #{} <{}>".split(' ')).format(
            book.title, book.id, book.url, sheet.title, sheet.id, sheet.url))
    else:
        print(g.sep.join("{} #{} <{}>".split(' ')).format(
            book.title, book.id, book.url))


def cmd_list_sheets(BOOK, services, g):
    cmd_sheets(BOOK, services, g)
def cmd_worksheets(BOOK, services, g):
    cmd_sheets(BOOK, services, g)

def cmd_sheets(BOOK, services, g):
    gc = gspread.service_account()
    ID = libgapi_mpe.gdrive_name_to_id(BOOK, services.drive)
    book = gc.open_by_key(ID)
    print(g.sep.join('# Title Rows Cols Id Url'.split(' ')))
    for sheet in book.worksheets():
        print(g.sep.join("{} {} {} #{} <{}>".split(' ')).format(
            sheet.title, sheet.row_count, sheet.col_count, sheet.id, sheet.url))

def cmd_all_sheets(BOOKS, services, g):
    gc = gspread.service_account()
    for BOOK in BOOKS:
        ID = libgapi_mpe.gdrive_name_to_id(BOOK, services.drive)
        book = gc.open_by_key(ID)
        for sheet in book.worksheets():
            print(g.sep.join("{} #{} <{}> {} {} {} #{} <{}>".split(' ')).format(
                book.title, book.id, book.url, sheet.title, sheet.row_count, sheet.col_count, sheet.id, sheet.url))

def cmd_permissions(TITLE_OR_ID, services, g):
    gc = gspread.service_account()
    ID = libgapi_mpe.gdrive_name_to_id(TITLE_OR_ID, services.drive)
    print(g.sep.join('# Name, Id, E-Mail, Type, Role'.split(' ')))
    for p in gc.list_permissions(ID):
        print(g.sep.join('{} #{} {} {} {}'.split(' ')).format(
                p['name'],
                p['id'],
                p['emailAddress'],
                p['type'],
                p['role']
            ))


def cmd_authorize(TITLE_OR_ID, USER, ROLE, services):
    ID = libgapi_mpe.gdrive_name_to_id(TITLE_OR_ID, services.drive)
    gc = gspread.service_account()
    if not ROLE: ROLE = 'writer'
    gc.insert_permission(ID, USER, perm_type='user', role=ROLE)


def cmd_about(service):
    "Show info about server-account credentials. "
    gc = gspread.service_account()
    print("Credentials Project Id: %s" % gc.auth.project_id)
    print("Client E-Mail: %s" % gc.auth.service_account_email)
    print("Scopes: %s" % " ".join(gc.auth.scopes))
    print("Signer-EMail: %s" % gc.auth.signer_email)
    print("Signer: %s" % gc.auth.signer)


commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')
commands.update(libcmd_docopt.command_handlers)
commands.update(libgapi_mpe.command_handlers)
commands.update(libgapi_mpe.gdrive_command_handlers)
commands.update(dict(
        count = libgapi_mpe.cmd_count_spreadsheets,
        list = libgapi_mpe.cmd_list_spreadsheets
    ))

def gspread_main(opts):
    g = opts.flags
    g.credentials = libgapi_mpe.load_secrets(opts.flags.token)
    libgapi_mpe.get_services(g, 'drive', 'sheets')
    if g.services: g.service = g.services.sheets
    else: log.warn("No services loaded")
    ret = libcmd_docopt.run_commands(commands, g, opts)
    if g.print_memory:
        libcmd_docopt.cmd_memdebug(g)
    return ret

def gspread_version():
    return 'x-gspread.mpe/%s' % __version__


if __name__ == '__main__':
    import sys
    reload(sys)
    sys.setdefaultencoding('utf8')
    opts = libcmd_docopt.get_opts(__description__+'\n'+__usage__,
            version=gspread_version(), defaults=gspread_defaults)
    sys.exit( gspread_main( opts ) )
