# Generic filesystem
declare -gA \
os_fs_ssc=(
[os_mine]='sudo chown $(id -u):$(id -g) "$@"'
[os_all_mine]='sudo chown $(id -u):$(id -g) -R "$@"'
)
