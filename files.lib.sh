#!/bin/sh

## Files: Listing and filtering by name, or descriptor

# Files are blobs or streams with associated name, path and descriptor (inode,
# times, permissions). Possibly extended attributes.

files_lib__load ()
{
  true "${package_lists_files:="scm"}"
}

files_list_local ()
{
  $LOG debug "" "Files list local..." "$package_lists_files"
  files_list ${package_lists_files} "$@"
}

files_list ()
{
  local srcset=${1:-"default"} ; shift

  case "$srcset" in

      default|local|package ) files_list_local "$@"  ;;

      all|find ) false # TODO: use find to list files
          ;;

      in-tag ) false # TODO: use tasks/contexts or other index
          ;;

      scm|tracked ) vc_tracked "$@" ;;

      scm-all )
          vc_tracked "$@"
          vc_untracked "$@" ;;

      * ) error "files-list: Unknown src-set name '$srcset'" 1 ;;
  esac
}

#
