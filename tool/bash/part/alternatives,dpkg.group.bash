declare -gA \
dpkg_alternatives_ssc=(

[alternatives.list]='update-alternatives -l "$@"'
[alternatives.list-selections]='update-alternatives --get-selections'

)
# Id: alternatives,us         vim:set ft=bash sw=2 sts=2 et:
