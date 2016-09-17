#!/bin/bash

function usage() {
  cat <<EOT
Usage: bash ${0##*/} <interface-name> <network-SSID> <password>
EOT
}

CONNECT_OPTION=''

# オプション解析
while getopts r OPT
do
    case $OPT in
        r)  CONNECT_OPTION="${CONNECT_OPTION} -r"
            ;;
        \?) usage && exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if [ $# -ne 3 ]; then usage && exit 1; fi

cd $(dirname $0)
arch=$(uname)
case "${arch}" in
    'Linux' | 'Darwin' )
        bash ./${arch}/connect_wifi.sh ${CONNECT_OPTION} $1 $2 $3 && bash ./${arch}/add_ssdp_route.sh $1
        exit $?
        ;;
    * )
        echo "The platform '${arch}' is not supported!"
        exit 1
        ;;
esac
