#!/bin/bash

qrcode_lib__load ()
{
  declare -ga qr_vers_size=(
    [1]=21
    [2]=25
    [3]=29
    [4]=33
    [5]=37
    [6]=41
    [7]=45
    [8]=49
    [9]=53
    [10]=57
    [11]=61
    [12]=65
    [13]=69
    [14]=73
    [15]=77
    [16]=81
    [17]=85
    [18]=89
    [19]=93
    [20]=97
    [21]=101
    [22]=105
    [23]=109
    [24]=113
    [25]=117
    [26]=121
    [27]=125
    [28]=129
    [29]=133
    [30]=137
    [31]=141
    [32]=145
    [33]=149
    [34]=153
    [35]=157
    [36]=161
    [37]=165
    [38]=169
    [39]=173
    [40]=177
  )
}

qrcode_lib__init ()
{
	true
}


qrcode_encode_tryvs () # ~ <Data> [ <version-ref> [ <qrencode-args...> ]]
{
	local try_ver
	local -n __version=${2:-version}
  # Generate QR codes with structured symbols
	for try_ver in {1..40}; do
			qrencode -v $try_ver --strict-version "${1:?}" "${@:3}" || continue
			echo "Success with Version $try_ver"
			__version=$try_ver
			break
	done
}

# Optionally, decode one QR code to check version (requires zbarimg)
#zbarimg qr_data-01.png

