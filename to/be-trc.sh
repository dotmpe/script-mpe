
# @be.trc

# Tasks where-ever they are are identified by Tag-ID, for all tasks acopy in
# the hub or documentation is expected in a predescribed format.
#
# This backends is to genereate and ensure unique ID's for a list of tags or slugs.

test -n "$trc_tags" ||
  trc_tags="$tasks_tags $tasks_coops"

lib_load tasks-trc

