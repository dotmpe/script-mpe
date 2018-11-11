#!/bin/sh

redo_baseline_tpl2__1__name='default.a.do'
redo_baseline_tpl2__1__contents='
redo-ifchange a.src
echo Test A >$3
redo-stamp <$3
'

redo_baseline_tpl2__2__name='default.b.do'
redo_baseline_tpl2__2__contents='
redo-ifchange test.a
echo Test B >$3
redo-stamp <$3
'

redo_baseline_tpl2__3__name='default.c.do'
redo_baseline_tpl2__3__contents='
redo-ifchange test.b
echo Test C >$3
redo-stamp <$3
'

redo_baseline_tpl2__4__name='a.src'
redo_baseline_tpl2__4__contents=''
