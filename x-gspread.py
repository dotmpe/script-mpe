# ENV-NAME: gspread-boreas
import os
import gspread
from oauth2client.service_account import ServiceAccountCredentials


GSPREAD_CREDS_JSON = os.getenv('GSPREAD_CREDS_JSON')
GSPREAD_SHEET_TITLE = os.getenv('GSPREAD_SHEET_TITLE')
#GSPREAD_WORKSHEET_NUM = ''
#GSPREAD_WORKSHEET_TITLE = ''
GSPREAD_WORKSHEET_RANGE = os.getenv('GSPREAD_WORKSHEET_RANGE')

if not GSPREAD_CREDS_JSON:
    raise Exception("GSPREAD_CREDS_JSON")

if not GSPREAD_SHEET_TITLE:
    raise Exception("GSPREAD_SHEET_TITLE")

if not GSPREAD_WORKSHEET_RANGE:
    raise Exception("GSPREAD_WORKSHEET_RANGE")

scope = ['https://spreadsheets.google.com/feeds']

credentials = ServiceAccountCredentials.from_json_keyfile_name(
        GSPREAD_CREDS_JSON, scope)

gc = gspread.authorize(credentials)

sheets = gc.open(GSPREAD_SHEET_TITLE)

sheet = sheets.sheet1
#sheet =sheets.get_worksheet(GSPREAD_WORKSHEET_NUM)
#sheet = sheets.worksheet(GSPREAD_WORKSHEET_TITLE)

# Fetch changelog
cell_list = sheet.range(GSPREAD_WORKSHEET_RANGE)
print cell_list

for x in cell_list:
    print x, type(x)

