#!/usr/bin/env bash

ctx_google_depends="@Std @Shell @Statusdir"
ctx_google_defines="@Google @GDrive @GSheets"

at_Google__init() #
{
  at_Google__login
}

at_Google__login() #
{
  x-gdrive.py login &&
  x-gspread.py login &&
  x-gcal.py login &&
  x-gtasks.py login
}

at_Google__reportlines () # ( [count] | names )
{
  x-gdrive.py login --valid && {
    echo "\$format index quotas @Google @Drive -- x-gdrive.py -o csv about quotas"
  } ||
      $LOG warn "" "No active login" x-gdrive

  x-gspread.py login --valid && {
    echo "\$format log sheets @Google @SpreadSheets -- x-gspread.py -n100 --all list"
    echo "\$format log folders @Google @SpreadSheets -- x-gspread.py -n100 --all list-folders"
    echo "\$format log files @Google @Drive -- x-gspread.py -n250 --all list-all"
  } ||
      $LOG warn "" "No active login" x-gspread

  x-gcal.py login --valid && {
    echo "log calendars @Google @Calendar -- x-gcal.py -n100 --all list"
  } ||
      $LOG warn "" "No active login" x-gcal

  x-gtasks.py login --valid && {
    echo "log tasks @Google @Tasks -- x-gtasks.py -n1000 --all list"
  } ||
      $LOG warn "" "No active login" x-gtasks
}

#
