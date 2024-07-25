#!/bin/sh

htd_man__couchdb='Stuff couchdb
  couchdb htd-scripts
  couchdb htd-tiddlers
'
htd__couchdb()
{
  # XXX: experiment parsing Sh. Need to address bugs and refactor lots
  #cd ~/bin && htd__couchdb_htd_scripts || return $?
  cd ~/hdocs && htd__couchdb_htd_tiddlers || return $?
}


htd__couchdb_htd_tiddlers()
{
  COUCH_DB=tw
  mkdir -vp $HTD_BUILDDIR/tiddlers
  find . \
    -not -ipath '*static*' \
    -not -ipath '*build*' \
    -not -ipath '*node_modules*' \
    -type f -iname '*.rst' | while read rst_doc
  do
    tiddler_id="$( echo $rst_doc | cut -c3-$(( ${#rst_doc} - 4 )) )"


    # Note: does not have the titles format=mediawiki mt=text/vnd.tiddlywiki
    format=html mt=text/html

    tiddler_file=$HTD_BUILDDIR/tiddlers/${tiddler_id}.$format
    mkdir -vp $(dirname $tiddler_file)
    pandoc -t $format "$rst_doc" > $tiddler_file

    wc -l $tiddler_file

    git ls-files --error-unmatch "$rst_doc" >/dev/null && {
      ctime=$(git log --diff-filter=A --format='%ct' -- $rst_doc)
      created=$(date \
        -r $ctime \
        +"%Y%m%d%H%M%S000")
      mtime=$(git log --diff-filter=M --format='%ct' -- $rst_doc | head -n 1)
      test -n "$mtime" && {
        modified=$(date \
          -r $mtime \
          +"%Y%m%d%H%M%S000")
      } || modified=$created
    } || {
      #htd_doc_ctime "$rst_doc"
      #htd_doc_mtime "$rst_doc"
      modified=$(date \
        -r $(filemtime "$rst_doc") \
        +"%Y%m%d%H%M%S000")
      created="$modified"
    }

    tiddler_jsonfile=$HTD_BUILDDIR/tiddlers/${tiddler_id}.json
    { cat <<EOM
    { "_id": "$tiddler_id", "fields":{
        "created": "$created",
        "modified": "$modified",
        "title": "$tiddler_id",
        "text": $(jsotk encode $tiddler_file),
        "tags": [],
        "type": "$mt"
    } }
EOM
    } > $tiddler_jsonfile

    curl -X POST -sSf $COUCH_URL/$COUCH_DB/ \
       -H "Content-Type: application/json" \
      -d @$tiddler_jsonfile

  done
}


# enter function listings and settings into JSON blobs per src
htd__couchdb_htd_scripts()
{
  local src= grp=
  test -n "$*" || set -- htd
  # *.lib.sh
  upper=false default_env out-fmt names
  groups="$( htd__list_function_groups "$@" | lines_to_words )"
  export verbosity=4 DEBUG=
  for src in "$@"
  do
    for grp in $groups
    do
      Inclusive_Filter=0 \
      Attr_Filter= \
        htd__filter_functions "grp=$grp" $src || {
          warn "Error getting 'grp=$grp' for <$src>"
          return 1
        }
    done
  done
}

#
