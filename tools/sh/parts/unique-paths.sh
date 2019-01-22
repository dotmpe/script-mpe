# Expand to realpath if exists, remove duplicates

unique-paths () # PATHNAME...
{
  for path in "$@"
  do
    test -e "$path" && realpath "$path" || echo "$path"
  done | remove-dupes
}
# Id: U-S:tools/sh/parts/unique-paths.sh                          vim:ft=bash:
