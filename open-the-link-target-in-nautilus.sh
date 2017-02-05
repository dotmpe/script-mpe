#!/bin/bash
#Title=open-the-link-target-in-nautilus
#Title[fr]=ouvrir-le-repertoire-cible-dans-nautilus

#==============================================================================
#                     open-the-link-target-in-nautilus
#
#  author  : SLK
#  version : v2010111601
#  license : Distributed under the terms of GNU GPL version 2 or later
#
#==============================================================================
#
#  description :
#    nautilus-script : 
#    open the target of a symbolic link of the selected object; if 
#    the target of the symbolic link is a file, open the parent folder
#
#  informations :
#    - a script for use (only) with Nautilus. 
#    - to use, copy to your ${HOME}/.gnome2/nautilus-scripts/ directory.
#
#  WARNINGS :
#    - this script must be executable.
#    - package "zenity" must be installed
#
#==============================================================================

#==============================================================================
#                                                                     CONSTANTS

# 0 or 1  - 1: doesn't copy but display a message - 0: copy
DRY_RUN=0

#==============================================================================
#                                                                INIT VARIABLES

# may depends of your system
AWK='/usr/bin/awk'
DIRNAME='/usr/bin/dirname'
GREP='/bin/grep'
LS='/bin/ls'
ZENITY='/usr/bin/zenity'

#==============================================================================
#                                                                          MAIN

[ -x "$ZENITY" ] || {
    echo "[ERROR] $ZENITY not found : EXIT"
    exit 1
}

first_selected_object=`echo "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" \
  | $AWK -F "\n" 'NR == 1 { print  $1; }'`

# check if local path
if [ `echo $first_selected_object | $GREP -c "^/"` -eq 0 ] ; then
    $ZENITY --error \
    --title "open-the-link-target-in-nautilus" \
    --text="[ERROR] $first_selected_object has not a valid path\n"
    exit 1
fi

# lets check if $first_selected_object is a symbolic link 
if [ -L "$first_selected_object" ] ; then
    # symbolic link : $target_link is the last field of ls -l
    target_link=`$LS -l "$first_selected_object" | $AWK -F "-> " '{print $NF}'`
    
    if [ `echo "$target_link" | $GREP -c "^/"` -eq 1 ] ; then
        # absolute path
        target="$target_link"
    else
        # relative path
        dirname_first_selected_object=`$DIRNAME "$first_selected_object"`
        target="$dirname_first_selected_object/$target_link"
    fi
else
    # not a symbolic link
    target="$first_selected_object"
fi

if [ -d "$target" ] ; then
    # target is a directory
    target_to_open_in_nautilus="$target"
else
    # target is a file, let's take the parent directory
    target_to_open_in_nautilus=`$DIRNAME "$target"`
fi

# go! go! go!
if [ $DRY_RUN -eq 1 ] ; then
    $ZENITY --info \
    --title "DEBUG" \
    --text="first_selected_object:$first_selected_object\ntarget_link:$target_link\ntarget:$target\ntarget_to_open_in_nautilus:$target_to_open_in_nautilus\n"
    exit 0
else
    nautilus --no-desktop "$target_to_open_in_nautilus"
fi


exit 0

$ZENITY --info \
--title "DEBUG" \
--text="DEBUG : not link $first_selected_object"
exit 0
### END


