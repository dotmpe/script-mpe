#!/bin/sh

htd_annex_lib__load ()
{
  lib_require date-htd match-htd bittorrent meta-annex share-htd infotab-htd \
    statdirtab-uc
}


#htd_annex_chdir ()
#{
#  cd "$ANNEX_DIR" ||
#    $LOG error : "ANNEX_DIR" "cd $ANNEX_DIR:E$?" $? || return
#}

#
