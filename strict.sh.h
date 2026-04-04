#
# Copyright 2008-2026 B. van Berkum <dev@dotmpe.com>
#
# Distributed under terms of the MIT license.
#if LANG == bash
set -euo pipefail
IFS=$' \t\n'
#elif LANG == dash
set -u
#elif LANG == zsh
set -uo pipefail
#else
#error unsupported shell LANG
#endif
# Id: strict.sh.h                               vim:set ft=bash sw=2 sts=2 et:
