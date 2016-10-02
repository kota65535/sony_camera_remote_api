#!/bin/bash

function usage() {
  cat <<EOT
Usage: bash ${0##*/} <network-SSID> <password> <interface-name>
EOT
}

CONNECT_OPTION=''

# Options
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

# Verify the number of arguments
if [ $# -ne 3 ]; then usage && exit 1; fi

cd $(dirname $0)
sysname=$(uname)
case "${sysname}" in
    'Linux')
        bash ./${sysname}/connect_wifi.sh ${CONNECT_OPTION} $1 $2 $3 && bash ./${sysname}/add_ssdp_route.sh $3
        exit $?
        ;;
    'Darwin')
        bash ./${sysname}/connect_wifi.sh ${CONNECT_OPTION} $1 $2    && bash ./${sysname}/add_ssdp_route.sh
        exit $?
        ;;
    * )
        echo "The system '${sysname}' is not supported!"
        exit 1
        ;;
esac
