declare -gA \
os_arch_ssc=(

[arch.add]='sudo pacman -S "$@"'
[arch.cycle]='arch.os.update'
[arch.remove]='sudo pacman -Rs "$@"'
[arch.os.refresh]='sudo pacman -Sy'
[arch.os.clean]='arch.os.clean-unused && arch.os.clean-cache'
[arch.os.clean-cache]='sudo pacman -Sc --noconfirm'
[arch.os.clean-unused]='pacman -Qdtq | sudo pacman -Rns - --noconfirm'
[arch.os.update]='sudo pacman -Syu --noconfirm && arch.os.clean'

)
# Id: arch,os                                    vim:set ft=bash sw=2 sts=2 et:
