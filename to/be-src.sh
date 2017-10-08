
# @be.src

# Tasks sourced from code comments. This relies on another backend being
# present track task ID.
# The src backend only has src names and lines for identification.

test -n "$src_path" ||
    src_path=~/bin

lib_load tasks-src

