declare -gA \
os_deb_ssc=(
# Fetch updates, upgrade and remove+clean
[debian-cycle]='sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean'
[debian-dpkg-is-installed]='dpkg -s "$@"'
)
#
