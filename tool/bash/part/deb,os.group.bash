declare -gA \
os_deb_ssc=(

# Fetch updates, upgrade and remove+clean
[debian.cycle]=debian.os.update
[debian.dpkg.is-installed]='dpkg -s "$@"'
[debian.nvidia.upgrade]='sudo apt purge *nvidia* && sudo apt install linux-headers-$(uname -r) && sudo apt install -y nvidia-driver && dkms status'
[debian.os.clean-packages]='sudo apt-get autoremove -y && sudo apt-get autoclean'
[debian.os.update]='sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean'
[debian.os.upgrade]='debian.os.update && sudo apt dist-upgrade && debian.os.clean-packages'
)
#
