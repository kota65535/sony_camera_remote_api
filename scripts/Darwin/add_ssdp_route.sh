#!/bin/bash
set -u
export LANG="C"

function usage() {
  cat <<EOT
Description:
  *** For MacOS ***
  Add a static route to the SSDP broadcast address via the specified interface.
  If interface is not given, the internal Wi-Fi device is used.
Usage:
  bash ${0##*/} <interface-name>
EOT
}

# Verify the number of arguments
if [ $# -gt 1 ]; then usage && exit 1; fi

if [ -z "${1+x}" ]; then
    # Get the device name associated with Wi-Fi network service
    WIFI_DEV_NAME=$(networksetup -listallhardwareports | grep -w Wi-Fi -A1 | awk '/^Device:/{ print $2 }')
    if [ -z "${WIFI_DEV_NAME}" ]; then
        echo "Internal Wi-Fi device not found!"
        exit 2
    fi
else
    # Verify the specified interface exists
    WIFI_DEV_NAME=$(networksetup -listallhardwareports | awk "/^Device: $1/{ print \$2 }")
    if [ -z "${WIFI_DEV_NAME}" ]; then
        echo "Specified interface not found!"
        exit 2
    fi
fi

# The broadcast address for SSDP discover
SSDP_ADDR=239.255.255.250


# Verify the existence of the route
route -n get ${SSDP_ADDR} | grep -q "interface: ${WIFI_DEV_NAME}"
if [ $? -eq 0 ]; then
  echo 'Route already configured.'
  exit 0
fi

# Add the route via the internal Wi-Fi device
route add -host ${SSDP_ADDR} -interface ${WIFI_DEV_NAME}
if [ $? -ne 0 ]; then
  echo "Failed to add route to ${SSDP_ADDR} via ${WIFI_DEV_NAME}"
  exit 1
fi

# Confirm the addition of the route completes
route -n get ${SSDP_ADDR} | grep -q "interface: ${WIFI_DEV_NAME}"
if [ $? -ne 0 ]; then
  echo "Something goes wrong!"
  exit 2
fi

echo 'Route added successfully.'
exit 0
