#!/bin/sh


annex_list()
{
  # Annex queries remotes, which may give errors (no network/mounts missing)
  git annex list $@ --fast 2>/dev/null | while read prefix file
  do
    test -e "$file" -o -h "$file" && echo "$file"
  done
}

# Print each file entries' metadata k/v. Pairs have liberal format, something
# like [^= ]+=.* Each pair on its own line, each entry separated by \f
# (form-feed) (and newline). Normally only prints files with metadata, if
# metadata is set the record is skipped (no output).
# set key_metadata to scan the Annex backend ID for metadata values;
# save time hashing.
# .*lastchanged attributes are removed
annex_metadata()
{
  while read file
  do
    key_metadata_=""
    test -z "$metadata_keys" || {
      annex_parsekey "$(basename "$(dirname "$(readlink "$file")")")"
      key_metadata_="size=$size\nkeys/sha2=$keys_sha2"
    }
    metadata_="$(git annex metadata "$file" | tail -n +2)"
    status="$(echo "$metadata_" | grep '^[a-z].*')"
    test "$status" = "ok" || {
        warn "Reading annex metadata '$file'"; continue; }
    falseish "$metadata_exists" || {
      test -e "$file" || {
          test -n "$metadata_" &&
          metadata_="exists=False\n$metadata_" ||
          metadata_="exists=False"
      }
    }
    metadata="$(echo "$metadata_" | grep '^ ')"
    test -n "$metadata$key_metadata_" || continue
    test -n "$metadadata" && metadadata="$metadadata\\n"
    printf -- "name=$file\\n$metadata$key_metadata_\\n\\f\\n"
  done |
    grep -v '.*lastchanged='
}

# List JSON for each file, but nostly no actual metadata will be present
annex_metadata_json()
{
  #git annex metadata -j | jq -cr 'walk( if type == "object" then with_entries( .key |= sub( "-lastchanged"; "" ) ) else . end )'
  #git annex metadata -j | jq -cr 'select(.fields!={}) | .fields | map({ tag })'
  #git annex metadata -j | jq -cr 'select(.fields!={}) | map(del(.fields.lastchanged))'
  git annex metadata -j |
      jq -cr 'select(.fields!={}) | with_entries(.key|=sub("-lastchanged";"")) | .file,.fields'
}

annex_parsekey()
{
  case "$1" in
    SHA256E-s*--* )
            KEY="$1"
            size=$(echo "$1" | cut -d'-' -f2 | cut -c2-)
            keys_sha2=$(echo "$1" | cut -d'-' -f4 | cut -d'.' -f1)
        ;;
    * ) error "Unknown key format '$1'" 1 ;;
  esac
}

# List keys (in SHA256E backend) from local GIT repo
annex_listkeys_local() # [Git-Dir]
{
  test -n "$1" || set -- .git
  # Keys have a double-level dir (with double-char name) prefix to allow storing
  # more files per dir than the filesystem allows at one level. Algorithm is
  # specified somewhere, but does not affect actual (SHA256E) key so it can be
  # ignored.
  for x in "$1"/annex/objects/*/*/*
  do
    annex_parsekey "$(basename "$x")"
    echo "$KEY"
  done
}

# List keys (in SHA256E backend) see annex-listkeys-local
annex_listkeys()
{
  test -n "$1" || set -- .
  ( cd "$1" && annex_listkeys_local )
}

annex_size()
{
  true
}
annex_dirsum()
{
  true
}
# Sum (byte)size for annexed content in Dir (and every subdir). Store JSON with
# metafile, relative to CWD
annex_dirsize() # Dir
{
  test -d "$1" || error "dir expected" 1
  dirsizes=.cllct/annex/tmp/dirsize
  meta=.cllct/annex/dirsize.json
  json_todir "$meta" "$dirsizes"
  find "$1" | while read -r path
  do
    test -d
    test $dirsizes/$1 -nt "$path"
  done
  json_fromdir "$meta" "$dirsizes"
}
