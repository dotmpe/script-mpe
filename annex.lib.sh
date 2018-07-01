#!/bin/sh


annex_list()
{
  # Annex queries remotes, which may give errors (no network/mounts missing)
  git annex list --fast 2>/dev/null | while read prefix file
  do
    test -e "$file" -o -h "$file" && echo "$file"
  done
}

# Print metadata k/v. Pairs have liberal format, something like [^= ]+=.*
annex_metadata()
{
  while read file
  do
    key_metadata_=""
    test -z "$key_metadata" || {
      KEY="$(basename "$(dirname "$(readlink "$file")")")"
      case "$KEY" in
        SHA256E-s*--* )
                size=$(echo "$KEY" | cut -d'-' -f2 | cut -c2-)
                keys_sha2=$(echo "$KEY" | cut -d'-' -f4 | cut -d'.' -f1)
                key_metadata_="size=$size\nkeys/sha2=$keys_sha2"
            ;;
      esac
    }
    metadata_="$(git annex metadata "$file" | tail -n +2)"
    status="$(echo "$metadata_" | grep '^[a-z].*')"
    test "$status" = "ok" || {
        warn "Reading annex metadata '$file'"; continue; }
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
