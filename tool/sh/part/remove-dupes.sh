#!/bin/sh

# Sort into lookup table (with Awk) to remove duplicate lines
remove_dupes() # ~
{
  awk '!a[$0]++'
}

# Id: U-S:tool/sh/part/remove-dupes.sh
# Id: BIN:tool/sh/part/remove-dupes.sh                          vim:ft=bash:
