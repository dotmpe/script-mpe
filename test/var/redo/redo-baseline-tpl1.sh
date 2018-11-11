#!/bin/sh

redo_baseline_tpl1__1__name='my/default.test1.do'
redo_baseline_tpl1__1__contents='
# Build another target if OOD
redo-ifchange second.test2
echo Test1 done
'

redo_baseline_tpl1__2__name='my/default.test2.do'
redo_baseline_tpl1__2__contents='
. ../some.sh
# Notify redo about source
redo-ifchange ../some.sh
echo Test2 done: $my_sh_var
'

redo_baseline_tpl1__3__name='some.sh'
redo_baseline_tpl1__3__contents='
my_sh_var=foo
'
