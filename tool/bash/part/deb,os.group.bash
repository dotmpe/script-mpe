declare -gA \
os_deb_ssc=(

# Fetch updates, upgrade and remove+clean
[debian.cycle]=debian.os.update
[debian.os.clean-packages]='sudo apt-get autoremove -y && sudo apt-get autoclean'

[debian.os.update]='sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean'
[debian.os.upgrade]='debian.os.update && sudo apt dist-upgrade && debian.os.clean-packages'

[debian.dpkg.is-installed]='dpkg -s "$@"'
)
#
