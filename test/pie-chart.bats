#!/usr/bin/env bats

base=pie-chart
load init
init

setup()
{ 
  rm -f _tmp/pie-chart*
  mkdir -p _tmp
}


@test "$base - gnuplot 3D chart. XXX: segments are missing" {

  gnuplot test/var/pie-chart/pie-chart.plot > _tmp/pie-chart.png
  #diff -bq test/var/pie-chart/pie-chart.png _tmp/pie-chart.png
}

@test "$base - gawk/gnuplot with tabular data" {

  mkdir -p _tmp

  test/var/pie-chart/pie-chart-awk-plot.sh test/var/pie-chart/pie-data.tab \
    > _tmp/pie-chart.plot
  diff -bq test/var/pie-chart/pie-chart.plot _tmp/pie-chart.plot

  gnuplot _tmp/pie-chart.plot > _tmp/pie-chart.png
  #diff -bq test/var/pie-chart/pie-chart.png _tmp/pie-chart.png
}
