#!/bin/sh

# Sort into lookup table (with Awk) to remove duplicate lines
remove_dupes() # ~
{
  awk '!a[$0]++'
}

# Id: U-S:tools/sh/parts/remove-dupes.sh
# Id: BIN:tools/sh/parts/remove-dupes.sh                          vim:ft=bash:
