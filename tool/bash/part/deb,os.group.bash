declare -gA \
os_deb_ssc=(

# Fetch updates, upgrade and remove+clean
[debian.cycle]=debian.os.update
[debian.dpkg.is-installed]='dpkg -s "$@"'
[debian.modified]='locate -ibe "*.dpkg-dist"'
[debian.nvidia.upgrade]='sudo apt purge *nvidia* && sudo apt install linux-headers-$(uname -r) && sudo apt install -y nvidia-driver && sudo dkms status'
[debian.add]='sudo apt install -qqy'
[debian.os.refresh]='sudo apt update -qq'
[debian.os.clean]='debian.os.clean-unused && debian.os.clean-cache'
[debian.os.clean-unused]='sudo apt-get autoremove -qqy'
[debian.os.clean-cache]='sudo apt-get autoclean'
[debian.os.update]='debian.os.refresh && sudo apt-get upgrade -qqy && debian.os.clean'
[debian.os.upgrade]='debian.os.update && sudo apt dist-upgrade && debian.os.clean'
[debian.remove]='sudo apt remove --purge -qq'

)
# Id: debian,os                                  vim:set ft=bash sw=2 sts=2 et:
