#!/bin/sh


#annex_lib_load()
#{
#  true
#}

annex_list()
{
  # Annex queries remotes, which may give errors (no network/mounts missing)
  git annex list --fast 2>/dev/null | while read prefix file
  do
    test -e "$file" && echo $file
    #fnmatch "|*" "$line" && {
    #} || {
    #}
  done
}

# Print metadata k/v. Pairs have liberal format, something like [^= ]+=.*
annex_metadata()
{
  while read file
  do
    metadata_=$(git annex metadata $file | tail -n +2)
    status=$(echo "$metadata_" | grep '^[a-z].*')
    test "$status" = "ok" || {
        warn "Reading annex metadata '$file'"; continue; }
    metadata=$(echo "$metadata_" | grep '^ ')
    test -n "$metadata" || continue
    echo "name=$file"
    printf -- "$metadata\n\f\n"
  done |
    grep -v '.*lastchanged='
}

annex_metadata_json()
{
  #git annex metadata -j | jq -cr 'walk( if type == "object" then with_entries( .key |= sub( "-lastchanged"; "" ) ) else . end )'
  #git annex metadata -j | jq -cr 'select(.fields!={}) | .fields | map({ tag })'
  #git annex metadata -j | jq -cr 'select(.fields!={}) | map(del(.fields.lastchanged))'
  git annex metadata -j |
      jq -cr 'select(.fields!={}) | with_entries(.key|=sub("-lastchanged";"")) | .file,.fields'
}
