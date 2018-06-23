#!/usr/bin/env bats

load init

setup()
{
  mkdir -vp build/py-MRO
}

@test "MRO graphviz test - static example code" {

  python res/py.py --test
  mv MRO_of_A.ps build/py-MRO/A-fig1.ps
  
  python res/py.py --test build/py-MRO/A-fig2.ps
  python res/py.py --test build/py-MRO/A-fig3.png
}

@test "MRO graphviz test for docutils.nodes" {
  python py-MRO-graph.py --du-test
}

@test "MRO graphviz for given classes" {
  python py-MRO-graph.py \
    script_mpe.res:{lst:{ListItemTxtParser,ListTxtParser},txt:AbstractTxtSegmentedRecordParser}
}
