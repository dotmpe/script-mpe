#!/usr/bin/env bash

todotxt_fields_lib__load ()
{
  : "${ggrep:=grep}"
}


todotxt_field_chevron_refs ()
{
  $ggrep -Po '(?<=<)[^ ]+(?=>)'
}

todotxt_field_context_tags ()
{
  $ggrep -Po '@[^ ]+'
}

todotxt_field_hash_tags ()
{
  $ggrep -Po '(?<=#)[^ ]+(?= |$)'
}

todotxt_field_meta_tags ()
{
  $ggrep -Po '[^ ]+:[^ ]+'
}

todotxt_field_project_tags ()
{
  $ggrep -Po '\+[^ ]+'
}

#
