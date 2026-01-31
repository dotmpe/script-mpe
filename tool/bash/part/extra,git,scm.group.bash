# Copyright: (C) 2026 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

scm_git_extra_pre=SCM.Git.x
scm_git_extra_cnk=b862d092
scm_git_extra_fun=(
)
declare -gA \
scm_git_extra_als=(
)
declare -gA \
scm_git_extra_ssc=(
)
declare -gA \
scm_git_extra_dep=(
)
declare -gA \
scm_git_extra_hooks=(
  [define]=\
': "${PROJECT_STATTAB:=$HOME/htdocs/.meta/stat/index/projects.list}"'
#  [init]=\
#''
)

SCM.Git.x.list-projects ()
{
:
# awk_grep_stattab_fields --id --tags @Git @Clone
  grep -E \
    -e '@Git( .*)?@Clone' \
    -e '@Clone( .*)?@Git' \
    "${PROJECT_STATTAB}"
}

SCM.Git.x.sync-projects-list ()
{
: some old 2023 script see src-local-sync.sh
}

# Id: extra,git,scm         vim:set ft=bash sw=2 sts=2 et:
