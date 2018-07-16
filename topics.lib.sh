#!/bin/sh


# Topics


topics_lib_load()
{
    true
}


create_topics()
{
# TODO: htd create-topics
#topic get $(basename $1) ||
#topic get $(basename $1) ||
  topic new $(basename $1) $(basename $(dirname $1))
}


# XXX: find local documents, extract topics
htd_topics_list()
{
  local find_ignores="$(find_ignores "$IGNORE_GLOBFILE")"
  eval local $(map=package_ext_topics_:topics_  package_sh  id  roots )
  test -n "$topics_roots" || topics_roots=.

  foreach_()
  {
      printf -- "$S "
      htd__tpath_raw "$S" ||
          printf -- "\n# Failure for '$S' ($?)\n"
  }
  foreach_setexpr

  eval find $topics_roots -false $find_ignores -o -iname \'"*.rst"\' -print |
      s= p= act=foreach_ foreach_do

  test -n "$topics_id" || error topic-list-id 1
}


htd_topics_save()
{
  test -n "$1" || error "Document expected" 1
  test -e "$1" || error "No such document $1" 1
  htd__tpaths "$1" | while read path
  do
    echo TODO $path
  done
  test -n "$topics_list_id" || error topic-list-id 1
}


htd_topics_commit()
{
  htd__topics | while read topic_path
  do
    topic get $(basename $topic_path) || create_topics $topic_path
  done
  test -n "$topics_list_id" || error topic-list-id 1
}


htd_topics_persist()
{
  while read topic_id topic_name topic_path
  do
    mkdir -vp $HTDIR/$topic_path
    mkdir -vp $HTDIR/$topic_path
  done
  test -n "$topics_list_id" || error topic-list-id 1
}
