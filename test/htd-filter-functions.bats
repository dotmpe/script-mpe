#!/usr/bin/env bats

load init
base=htd-filter-functions

setup()
{
  init
  export Inclusive_Filter=0
}

#htd filter-functions "run=..*" htd
#htd filter-functions  "grp=htd-meta spc=..*" htd

#echo 1.yaml
#export Inclusive_Filter=0
#export out_fmt=yaml
#htd filter-functions "grp=box-src spc=..*" htd
#echo
#
#echo 1.json:
#export out_fmt=json
#htd filter-functions "grp=box-src spc=..*" htd
#echo
#
#echo 1.csv:
#export out_fmt=csv
#htd filter-functions "grp=box-src spc=..*" htd
#echo

@test "${base}: YAML" {
  out_fmt=yaml htd filter-functions "grp=tmux" htd | jsotk yaml2json --pretty
}

@test "${base}: SRC" {
  out_fmt=src htd filter-functions "grp=tmux" htd
}

@test "${base}: CSV" {
  out_fmt=csv htd filter-functions "grp=tmux" htd
}

@test "${base}: JSON" {
  out_fmt=json htd filter-functions "grp=tmux" htd
}
