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
            sha2=$(echo "$1" | cut -d'-' -f4 | cut -d'.' -f1)
            keys_sha2="$sha2"
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

git_annex_unusedkeys_findlogs() # Key-List-File...
{
  test -s "$1" || { error "git_annex_unusedkeys_findlogs File expected" ; return 1; }
  local x=0
  while test -n "$1"
    do
    while read -r key rest
    do
      test -n "$key" -a "$(echo "${key}" | cut -c1 )" != "#" || continue
      x=$(( $x + 1 ))
      echo Key $x: $key
      test -e "$log" || git log --stat -S"$key" > "$log"
      cat "$log"
      echo
    done < "$1"
    shift
  done
}

git_annex_dropkeys()
{
  while read -r key
  do
    git annex dropkey --force $key || continue
  done
}

git_annex_unusedkeys_drop_ifloggrep() # Key-List-File Grep...
{
  test -s "$1" || { error "git_annex_unusedkeys_drop_ifloggrep File expected" ; return 1; }
  test -n "$2" || { error "Grep expected" ; return 1; }
  local list="$1" x=0; shift
  while read -r key rest
  do
    test -n "$key" -a "$(echo "${key}" | cut -c1 )" != "#" || continue
    x=$(( $x + 1 ))
    echo Key $x: $key
    log=.cllct/annex-unused/$key.log
    test -e "$log" || git log --stat -S"$key" > "$log"
    for pat in $@
    do
      grep "$pat" "$log" && {
        git annex dropkey --force "$key" || true
        rm "$log"
        grep -qF "$key" dropped.list || echo "$key" >>dropped.list
        break
      } || continue
    done
  done < "$list"
}

git_annex_unusedkeys_backupfiles() # Key-List-File
{
  test -n "$target" || target=$HOME/htdocs/cabinet/.git/annex/
  path=
  while test -n "$1"
  do
    while read -r key path
    do
      test -n "$key" -a "$(echo "${key}" | cut -c1 )" != "#" || continue
      annexed="$( git annex contentlocation "$key" || true )"
      test -e "$annexed" || {
        trueish "$DEBUG" && stderr "No local content for '$key'" || true
        continue
      }
      stderr "Backup: $key to $path"
      annex_parsekey "$key"
      test $size = $(filesize "$annexed") || {
        stderr "Corrupt file: Filesize mismatch for $key" 1
        continue
      }
      test -z "$path" -a -e ".cllct/annex-unused/$key.log.path" &&
        path=$( head -n 1 ".cllct/annex-unused/$key.log.path") || true
      test -n "$path" && {
        test -e "$path" || {
          mkdir -p "$(dirname "$path")"
          chmod ug+rw "$annexed" "$(dirname "$annexed")" "$(dirname "$path")"
          rsync -avzui "$annexed" "$path"
          echo "$keys_sha2  $(basename "$path")" > $path.sha2sum
        }
        git annex dropkey --force "$key" || true
        echo "$key" >> dropped.list
        continue
      } || {
        content="$(find $target -type f -iname "$key")"
        test -z "$content" || {
          test -e "$content" || continue
          test $size = $(filesize "$content") && {
            #stderr "Content $key exists at $target"
            git annex dropkey --force "$key"
            continue
          } || {
            stderr "Content for $key missing at $target"
          }
        }
        stderr "Path for $key missing at $target"
        continue
      }
    done < "$1"
    shift
  done
}

annex_contentexists() # Dir SHA256E-Key
{
  local cwd="$(pwd)"
  content_location="$(cd "$1" && git annex contentlocation "$2" || true)"
  cd "$cwd"
  test -n "$content_location" -a -s "$1/$content_location" || return $?
}

annex_keyexists() # Dir SHA256E-Key
{
  local cwd="$(pwd)"
  content_location="$(cd "$1" && git annex contentlocation "$2" || true)"
  cd "$cwd"
  stderr 0 "Content Location $content_location"
  test -n "$content_location" || return $?
}
