
VAR2_1a    =   foo
VAR2_1b    :=  foo

VAR2_2a    =   $(VAR2_1a)
VAR2_2b    =   $(VAR2_1a)

VAR2_2a    ?=  bar-a-1
VAR2_2a    +=  bar-a-2

VAR2_2b    ?=  bar-b-1
VAR2_2b    +=  bar-b-2

default:: ;
