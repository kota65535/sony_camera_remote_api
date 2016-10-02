#!/bin/bash
set -u
export LANG="C"

function usage() {
  cat <<EOT
Description:
  Connect to the specified wireless network.
Usage:
  bash ${0##*/} [options] <network-SSID> <password> <interface-name>
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
if [ $# -ne 3 ]; then usage && exit 1; fi

# Verify the existence of specified interface
iwconfig $3 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Specified interface '$3' not found."
    exit 2
fi

# If --restart option is not given, exit if already connected.
if [ -z ${FLAG_RESTART+x} ]; then
    # Exit if already connected
    iwconfig $3 | grep -wq "ESSID:\"$1\"" && ifconfig $3 | grep -q 'inet addr'
    if [ $? -eq 0 ]; then
        echo "Already connected."
        exit 0
    fi
fi

# Restart the interface
POWER_ON_WAIT=1
ifconfig $3 down
ifconfig $3 up
if [ $? -ne 0 ]; then
    echo "Failed to activate interface '$3'"
    exit 3
fi
sleep ${POWER_ON_WAIT}

# Scan networks with specified SSID
SCAN_RETRY=4
SCAN_INTERVAL=15
try=1
while true; do
    iwlist $3 scan | grep -wq "ESSID:\"$1\""
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

# Kill if wpa_supplicant is alive
pkill -f "wpa_supplicant.+-i *$3 .*"

# Set SSID for the interface
iwconfig $3 essid $1

# Try to connect
WPA_AUTH_TIMEOUT=30
is_connected=false
current_time=$(date +%s)
# Run wpa_supplicant by nohup. stdbuf is introduced to prevent buffering.
while read -t ${WPA_AUTH_TIMEOUT} line; do
    echo "  $line"
    # Judge from the output log
    echo $line | grep -wq 'CTRL-EVENT-CONNECTED'
    if [ $? -eq 0 ]; then
        is_connected=true
        break
    fi
    # Is timeout?
    if [ $(($(date +%s) - ${current_time})) -gt ${WPA_AUTH_TIMEOUT} ]; then
        echo "Timeout."
        break
    fi
done < <(nohup bash -c "wpa_passphrase $1 $2 | stdbuf -oL wpa_supplicant -B -i $3 -D wext -c /dev/stdin -f /dev/stdout")
# done < <(nohup bash -c "wpa_passphrase $1 $2 | stdbuf -oL wpa_supplicant -i $3 -D wext -c /dev/stdin 2>&1 | stdbuf -oL tee wpa.log &")
if ! $is_connected; then
    echo 'WPA authentication failed.'
    pkill -f "wpa_supplicant.+-i *$3 .*"
    exit 5
fi

# Assign IP address by DHCP
ifconfig $3 | grep -q 'inet addr'
if [ $? -ne 0 ]; then
    dhclient $3
    ifconfig $3 | grep -q 'inet addr'
    if [ $? -ne 0 ]; then
        echo 'IP address cannot not be assgined.'
        exit 6
    fi
fi

echo 'Connected successfully.'
exit 0
