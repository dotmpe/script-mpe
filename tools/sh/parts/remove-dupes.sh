# Sort into lookup table (with Awk) to remove duplicate lines
remove-dupes() # ~
{
  awk '!a[$0]++'
}
# Id: U-S:tools/sh/parts/remove-dupes.sh                          vim:ft=bash:
