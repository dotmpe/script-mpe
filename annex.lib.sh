#!/bin/sh

## Annex: GIT annex wrappers (consolidate and lock media-file versions)


annex_lib_load()
{
  : "${ANNEX_DIR:?}"
  content_annices="$ANNEX_DIR/archive-old $ANNEX_DIR/backup $ANNEX_DIR/photos"

  # TODO: scan for .annex/objects folder, move this to user-conf
  #content_annices="$()"
}

annex_init()
{
  #shellcheck disable=SC1090 # follow non-constant source
  . ~/.local/composure/find_by_sha2.inc
}

htd_annex_files()
{
  # Annex queries remotes, which may give errors (no network/mounts missing)
  git annex list "$@" --fast 2>/dev/null | while ${read:-read -r} prefix file
  do
    test -e "$file" -o -h "$file" && echo "$file"
  done
}

# Print each file entries' metadata k/v. Pairs have liberal format, something
# like [^= ]+=.* Each pair on its own line, each entry separated by \f
# (form-feed) (and newline). Normally only prints files with metadata. If
# metadata_exists is true, a boolean wether file exists is added. With
# metadata_keys on the SHA256E backend key is split up into a size and keys/sha2
# field.
# .*lastchanged attributes are removed
annex_metadata()
{
  while read -r file
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
    printf -- "name=%s\\n%s\\n\\f\\n" "$file" "$metadata$key_metadata_"
  done |
    grep -v '.*lastchanged='
}

git_annex_metadata ()
{
  git annex metadata "$@" | {
    local count=0 file fields
    while IFS=$'\t\n' read -r line
    do
      test -n "$line" || continue
      test "${line:0:1}" != " " && {
        test "${line:0:2}" != "ok" && {
          file=${line:9}
          count=$(( count + 1 ))
          fields=
        } || {
          test -n "$fields" || continue
          echo "$file"
          echo "  ${fields//$'\n'/$'\n  '}"
        }
      } || {
        fnmatch "*lastchanged=*" "$line" && continue
        fields="${fields:-}${fields:+$'\n'}${line:2}"
      }
    done
    $LOG notice : "Checked $count files"
  }
}

git_annex_metadata2 ()
{
  git annex metadata "$@" | {
    local count=0 file fields field ifs=$'\t\n'
    while true
    do
      read -r _ file || break
      test -n "$file"
      IFS=$ifs read -r field
      while test "${field:0:1}" = " "
      do
        fnmatch "*lastchanged=*" "$field" ||
            fields="${fields:-}${fields:+$'\n'}${field:2}"
        IFS=$ifs read -r field
      done
      test -n "$fields" -o -z "$field" || return 21 # fields or empty line expected
      test -n "$field" && stat=$field || read -r stat
      test "$stat" = "ok" || return 22
      fields=file=$file$'\n'$fields
      kv_quote "=" <<< "$fields"
      echo
      unset fields
    done
  }
}

# List JSON for each file, but nostly no actual metadata will be present
annex_metadata_json()
{
  #git annex metadata -j | jq -cr 'walk( if type == "object" then with_entries( .key |= sub( "-lastchanged"; "" ) ) else . end )'
  #git annex metadata -j | jq -cr 'select(.fields!={}) | .fields | map({ tag })'
  #git annex metadata -j | jq -cr 'select(.fields!={}) | map(del(.fields.lastchanged))'

  # Annex 6.0 and jq 1.5 minimum

  git annex metadata -j |
    # Ignore  illegal json for files w/o metadata
    grep -v ',,'
  return
  #  |
  #  jq -r 'select(.fields!={} and .fields!=null) | .file,.fields'
  #return

  # Requires jq 1.5
  git annex metadata -j |
      jq -r 'select(.fields!={}) | with_entries(.key|=sub("-lastchanged";"")) | .file,.fields'
}

# Parse annex SHA256E key into size, sha2, keyext
annex_parsekey()
{
  case "$1" in
    SHA256E-s*--* )
            KEY="$1"
            size=$(echo "$1" | cut -d'-' -f2 | cut -c2-)
            sha2=$(echo "$1" | cut -d'-' -f4 | cut -d'.' -f1)
            keyext=$(echo "$1" | cut -d'-' -f4 | cut -d'.' -f2-)
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
  false
}
annex_dirsum()
{
  false
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
  while test $# -gt 0
    do while read -r key rest
      do test -n "$key" -a "$(echo "${key}" | cut -c1 )" != "#" || continue
      x=$(( x + 1 ))
      echo Key $x: $key
      test -e "$log" || git log --stat -S"$key" > "$log"
      cat "$log"
      echo
    done < "$1"
    shift
  done
}

# One dropkey --force, for given filename or empty
annex_dropbykey() # File Key
{
  local size sha2 keyext KEY keys_sha2 fn
  set_cataloged_file "$1" || true
  note "Dropping '$1'.."
  # NOTE: content does need to be present, key should exist ofcourse
  annex_parsekey "$2" || return
  std_info "Dropping KEY=$2.."
  git annex dropkey --force "$2" || echo dropkey-exit=$?
  test -n "$dropped" || dropped=./.catalog/dropped.sha2list
  test -n "$1" || set -- "$keyext" "$2"
  grep -q "$2" $dropped && {
    note "Already recorded as dropped: '$1'"
  } || {
    test -z "$reason" || set -- "$1\t$reason" "$2"
    echo "$size $sha2 $1" >> $dropped
  }
  test -z "$fn" -o ! -e "$fn" || git rm "$fn"
}

# Just dropkey --force. Read keys (and optional filename) from stdin.
annex_dropkeys()
{
  while read -r key fn
  do
    annex_dropbykey "$fn" "$key"
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
    x=$(( x + 1 ))
    echo Key $x: $key
    log=.cllct/annex-unused/$key.log
    test -e "$log" || git log --stat -S"$key" > "$log"
    for pat in "$@"
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
  #test -n "$target" || target=$HOME/htdocs/cabinet/.git/annex/
  test -n "$target" || target="/srv/$(readlink /srv/annex-local)/backup/.git/annex"
  path=
  while test $# -gt 0
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
  content_location="$(cd "$1" && git annex contentlocation "$2" || true)"
  test -n "$content_location" -a -s "$1/$content_location" || return $?
}

annex_keyexists() # Dir SHA256E-Key
{
  content_location="$(cd "$1" && git annex contentlocation "$2" || true)"
  stderr 0 "Content Location $content_location"
  test -n "$content_location" || return $?
}

annexed_file ()
{
  # XXX: this assumes the usual SHA256(E) backend
  test -h "$1" || return 1
  case "$(realpath -m "$1")" in */.git/annex/objects/* ) ;; ( * ) return 1 ;; esac
  #objectdir="$(dirname "$(dirname "$(dirname "$(dirname "$(realpath -mq "$1")")")")")"
  #gitdir="$(dirname "$(dirname "$(dirname "$objectdir")")")"
  #test "${objectdir:${#gitdir}}" = "/.git/annex/objects"
}

annex_file_is_here ()
{
  test -h "$1" || return 0
  test -e "$1"
}

annex_files_are_here ()
{
  find "$1" -type f -o -type l | while read -r f
    do
        test -s "$f" || return
    done
}

annex_info_parsehere()
{
  info_raw="$(git annex info | grep here)"
  info_uuid="$(echo $info_raw | cut -d ' ' -f1  )"
  info_descr="$(echo $info_raw | cut -d ' ' -f3- )"
}

annex_fsckfast_cache()
{
  local r=0
  git annex fsck  --fast >.cllct/annex-fsck.list 2>.cllct/annex-fsck-err.list || r=$?
  wc -l .cllct/annex-fsck-err.list
  rm .cllct/annex-fsck.list
  test -s .cllct/annex-fsck.list || rm .cllct/annex-fsck.list
  return $r
}

annex_dropkeys_fromother() # Other-Annex
{
  test -n "$1" || stderr 0 "Other-Annex expected" 1
  find $1/.git/annex/objects -type f | while read -r cl
  do
    test -n "$cl" -a -e "$cl" || continue
    key="$(basename "$cl")"
    git annex drop --force "$key" || continue
  done
}

annex_and_move()
{
  git annex add "$1" &&
  mkdir -p "$2" &&
  git mv "$1" "$2"/
}

annexdir_update()
{
  lib_load package
  r=0
  for x in ./*/
  do
    test -d "$x/.git/annex" || { warn "Not an annex '$x'" ; continue; }

    # TODO: may want to check package for init script
    package_file "$x" || {
        warn "No package file found in '$x'"
        continue
      }

    # XXX: which env to load? TOOLS_SUITE=main?
    test $x/.meta/package/envs/main.sh -nt "$metaf" &&
      note "Package up-to-date for $x" || {

        package_sh_list_exists "init" && {
          ( cd "$x" && htd.sh run init ) || return
        } || {
          ( cd "$x" &&
              htd.sh package update &&
              htd.sh package remotes-reset &&
              vc.sh regenerate ) || return
        }
      }
  done
  return $r
}
annexdir_sync()
{
  r=0
  for x in ./*/
  do
    test -d "$x/.git/annex" || { warn "Not an annex '$x'" ; continue; }
    (
      cd "$x" && git annex sync
    )
  done
  return $r
}
annexdir_get()
{
  test -n "$1" || set -- --auto
  #test -n "$1" || set -- .
  std_info "Annexdir get '$*'..."
  # From Annex/* dir, sync and an get all
  for a in "$PWD"/*/
  do
    echo "$a"
    test -e "$a/.git" || continue
    test -d "$a/.git/annex" || { warn "Not an annex '$a'" ; continue; }
    cd "$a" && git annex sync && git annex get "$@"
  done
}
annexdir_getpref()
{
  annexdir_get --auto
}
annexdir_run()
{
  r=0
  test -n "$*" || set -- git status
  for x in ./*/
  do
    test -d "$x/.git" || { warn "Not an repository '$x'" ; continue; }
    test -d "$x/.git/annex" || warn "Not an annex '$x'"
    basename "$x"
    (
      cd "$x" && command "$@"
    )
  done
  return $r
}
annexdir_check()
{
  local r=0
  for x in ./*/
  do
    test -d "$x/.git/annex" && continue
    test -d "$x/.git" &&
      error "Not an Annex repo: '$x'" ||
      error "Not an GIT repo: '$x'"

  done
  return $r
}

annex_dropbyname()
{
  KEY="$(git annex lookupkey "$1")" || return
  annex_dropbykey "$1" "$KEY"
}

# Lookup by SHA256E key or SHA-2, in every annex found in dir.
annices_findbysha2list()
{
  while read -r size sha2 fn
  do
    test -n "$fn" -a -f "$fn" || continue
    ext="$(filenamext "$fn")"
    KEY="SHA256E-s${size}--${sha2}.$ext"
    #annices_lookup_by_key "$KEY" && { continue; }
    #annices_lookup_by_sha2 "$sha2" && { continue; }
    rs="$(annices_lookup_by_key "$KEY")" && { echo "$rs"; continue; }
    rs="$(annices_lookup_by_sha2 "$sha2")" && { echo "$rs"; continue; }
    fnmatch "* *" "$fn" && warn "Illegal filename"
    echo "$fn"
  done
}

# Go over annices looking for key, echo annex path on success. Also,
# contentlocation will be set to the local file path.
annices_lookup_by_key()
{
  std_info "Lookup by key '$1'.."
  for annex in "$ANNEX_DIR"/*/
  do
    test -d "$annex/.git/annex/objects" || {
      continue # No content in annex
    }
    debug "Annex '$annex'.."
    (
      cd "$annex" &&
      contentlocation="$(git annex contentlocation "$1" || true)"
      test -n "$contentlocation" && {
        test -e "$contentlocation" && {
          echo "$1 $annex $contentlocation"
        } || {
          echo "$1 $annex"
        }
        return 0
      }
    ) && return
    # No occurrence in '$annex'
    continue
  done
  return 1
}

# Go over annices looking for sha2, then get key and output as lookupbykey
# instead key is a sha2. Set env backendfile and KEY as well.
annices_lookup_by_sha2()
{
  std_info "Lookup by SHA-256 '$1'.."
  for annex in "$ANNEX_DIR"/*/
  do
    test -d "$annex/.git/annex/objects" || {
      continue # No content in annex
    }
    debug "Annex '$annex'.."
    (
      cd "$annex" &&
      backendfile="$(find .git/annex/objects -type f -iname "SHA256*--$1*" | head -n 1)"
      test -n "$backendfile" && {
        KEY="$(basename "$backendfile")"
        contentlocation="$(git annex contentlocation "$KEY" || true)"
        test -n "$contentlocation" || error "$KEY" 1
        test -e "$contentlocation" && {
          echo "$1 $annex $contentlocation"
        } || {
          echo "$1 $annex"
        }
        return 0
      }
    ) && return
    # No occurrence in '$annex'
    continue
  done
  return 1
}

annices_scan_for_sha2()
{
  test -n "$1" || stderr 0 "SHA2 expected" 1
  local cwd="$PWD"
  for annex in $content_annices
  do
    cd "$annex" &&
    git grep -q "$1" && {
      cd "$pwd";
      stderr 0 "SHA2 for $fn found at $annex"
      return;
    } || continue
  done
  cd "$cwd" || return
  return 1
}

annex_status ()
{
  annex_unused_cachelist
}

annex_unused_cachelist()
{
  mkdir -vp .cllct/annex-unused
  test -n "$info_uuid" || annex_info_parsehere
  out=.cllct/annex-unused/repo-$info_uuid.list
  git annex unused > $out
  unused=$(count_lines $out)
  test $unused -gt 1 &&
    stderr 0 "Unused files: $(( unused - 1 )) <$out>" || rm "$out"
}

git_annex_find_keys ()
{
  find .git/annex/${1:?} -type f -iname "${2:?}"
}

git_annex_find_objects ()
{
  git_annex_find_keys "objects" "$@"
}

git_annex_find_corrupt ()
{
  git_annex_find_keys "bad" "$@"
}

git_annex_add_at () # ~ <Src> <Dest>
{
  rsync -avzui --no-group "$1" "$2" && git annex add "$2"
}

#
