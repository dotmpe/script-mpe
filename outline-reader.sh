
# TODO: simple txt outline for source files

#uc_script_load user-script

lib_load os-htd rules

set -- $HOME/.statusdir/index/context.list
set -- ${US_BIN:?}/var/txt/simple-source-outline.txt

. ${US_BIN:?}/outline.sh

outline_fetch "$1"
#outline.py read "$1"
#< "$1" \
#read_nix_style_file |
#outline_reader
