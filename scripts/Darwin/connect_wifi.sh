#!/bin/bash
set -u
export LANG="C"

function usage() {
  cat <<EOT
Description:
  *** For Mac ***
  Connect to the specified wireless network.
  Cannot be used with a third-party Wi-Fi adapter.
Usage:
  bash ${0##*/} <network-SSID> <password>
Option:
  -r : restart interface even if already connected.
EOT
}

# Options
while getopts r OPT
do
    case $OPT in
        r)  FLAG_RESTART=1
            ;;
        \?) usage && exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Verify the number of arguments
if [ $# -ne 2 ]; then usage && exit 1; fi

# Get the device name associated with Wi-Fi network service
WIFI_DEV_NAME=$(networksetup -listallhardwareports | grep -w Wi-Fi -A1 | awk '/^Device:/{ print $2 }')
if [ -z "${WIFI_DEV_NAME}" ]; then
  echo "Internal Wi-Fi device not found!"
  exit 2
fi

# If --restart option is not given, exit if already connected.
if [ -z ${FLAG_RESTART+x} ]; then
    networksetup -getairportnetwork ${WIFI_DEV_NAME} | grep -wq $1
    if [ $? -eq 0 ]; then
        echo 'Already connected.'
        exit 0
    fi
fi

# Power ON the interface if not.
POWER_ON_WAIT=1
networksetup -getairportpower ${WIFI_DEV_NAME} | grep -wiq 'off'
if [ $? -eq 0 ]; then
  networksetup -setairportpower ${WIFI_DEV_NAME} on
  if [ $? -ne 0 ]; then
    echo "Failed to power on ${WIFI_DEV_NAME}."
    exit 3
  fi
  sleep ${POWER_ON_WAIT}
fi

# Full path of airport command
AIRPORT_CMD='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport'

# Scan networks with specified SSID
SCAN_RETRY=4
SCAN_INTERVAL=15
try=1
while true; do
    ${AIRPORT_CMD} --scan=$1 | grep -wq $1
    if [ $? -eq 0 ]; then
        break
    elif [ ${try} -eq ${SCAN_RETRY} ]; then
        echo "The wi-fi network with SSID '$1' not found."
        exit 4
    fi
    ((try++))
    echo "Scan failed, retrying... (${try}/${SCAN_RETRY})"
    sleep ${SCAN_INTERVAL}
done

# Try to connect
CONNECTION_RETRY=3
RETRY_INTERVAL=2
remain=${CONNECTION_RETRY}
while [ ${remain} -gt  0 ]
do
  # Judge from the output because 'networksetup -setairportnetwork' returns always 0.
  networksetup -setairportnetwork ${WIFI_DEV_NAME} $1 $2 | grep -wq 'Error'
  if [ $? -ne 0 ]; then
    break
  fi
  ((remain--))
  sleep ${RETRY_INTERVAL}
done
if [ ${remain} -eq 0 ]; then
  echo "Failed to join the network. Password may be incorrect."
  exit 5
fi

# Confirm the connection completes.
networksetup -getairportnetwork ${WIFI_DEV_NAME} | grep -wq $1
if [ $? -ne 0 ]; then
  echo 'Something wrong occured!'
  exit 6
fi

echo 'Connected successfully.'
exit 0
