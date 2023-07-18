# Build static source analysis indices
redo-ifchange "$REDO_BASE/.cllct/src/sh-libs.list"

cut -f 1 -d '	' "$REDO_BASE/.cllct/src/sh-libs.list" | while read -r comp_id
do
    # XXX: only main libs
    test -e "$REDO_BASE/$comp_id.lib.sh" || continue
    echo "Lib '$comp_id'..." >&2

  redo-ifchange "$REDO_BASE/doc/src/sh/$comp_id-lib.calls-1.dot.gv"
done
#
