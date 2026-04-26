# .group.bash file, see User-Conf us-part for specification.
#
# Copyright 2008-2026 B. van Berkum <dev@dotmpe.com>
#
# Distributed under terms of the MIT license.
us_metadir_pre=User-Script.Metadir
us_metadir_cnk=d3df3db4

declare -gA \
us_metadir_ssc=(
  [metadir.findall]='local {meta,sub}dirs
mapfile -t metadirs < <(locate -ie "*/.meta") &&
for metadir in "${metadirs[@]}"
do find "$metadir" -exec realpath --relative-to "$metadir" {} \;; done |
  remove_dupes_or_hidden'

  [metadir.findall+dirs]='local {meta,sub}dirs
mapfile -t metadirs < <(locate -ie "*/.meta") &&
mapfile -t subdirs < <(for metadir in "${metadirs[@]}"
do find "$metadir" -type d -exec realpath --relative-to "$metadir" {} \;; done |
  remove_dupes_and_current ) &&
printf.lines.array subdirs'

  [metadir.findall+files]='local metadirs subpaths
mapfile -t metadirs < <(locate -ie "*/.meta") &&
mapfile -t subpaths < <(for metadir in "${metadirs[@]}"
do find "$metadir" -type f -exec realpath --relative-to "$metadir" {} \;; done |
  remove_dupes ) &&
printf.lines.array subpaths'

  [metadir_ok]='[[ -d "$EWD" && -d "$METADIR"/config ]]' # && -s "$METADIR/config/dir.id" ]]'
  [metadir_init]='[[ -d "$1" ]] &&
mkdir "$1"/{cache,build,config,stat}'
)

declare -gA \
us_metadir_hooks=(
#  [init]=\
#''
)

# Id: metadir,us         vim:set ft=bash sw=2 sts=2 et:
