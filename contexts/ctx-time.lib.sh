#!/bin/sh

# Execute at least once every day.
ctx__Daily__sh_rules() # ~
{
  test stat .. && { jk } || return ;
}

# 1n 1u 1ms 1s 4m 3h 15D 4M 1Y
ctx__time__sh_rules() # ~
{
  true
}

# p<num> for priority; prefix lines with prio and sort
ctx__priority__sh_rules() # ~
{
  true
}

#
