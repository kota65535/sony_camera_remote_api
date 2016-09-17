#!/bin/bash
set -u
export LANG="C"

function usage() {
  cat <<EOT
Usage:  bash ${0##*/} [options] <interface-name> <network-SSID> <password>
Option: -r : restart interface even if already connected.
EOT
}

# オプション解析
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

# 引数チェック
if [ $# -ne 3 ]; then usage && exit 1; fi

# 指定されたインターフェースが存在するか調べる
iwconfig $1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Device named '$1' not found."
    exit 2
fi

# -rオプション有りなら接続済みでも再接続
if [ -z ${FLAG_RESTART+x} ]; then
    # すでに接続されていれば終了
    iwconfig $1 | grep -wq "ESSID:\"$2\"" && ifconfig $1 | grep -q 'inet addr'
    if [ $? -eq 0 ]; then
        echo "Already connected."
        exit 0
    fi
fi

# インターフェースを再起動
POWER_ON_WAIT=1
ifconfig $1 down
ifconfig $1 up
if [ $? -ne 0 ]; then
    echo "Failed to activate interface $1"
    exit 3
fi
sleep ${POWER_ON_WAIT}

# 指定のSSIDを持つアクセスポイントがあるか調べる
SCAN_RETRY=4
SCAN_INTERVAL=10
try=1
while true; do
    iwlist $1 scan | grep -wq "ESSID:\"$2\""
    if [ $? -eq 0 ]; then
        break
    elif [ ${try} -eq ${SCAN_RETRY} ]; then
        echo "The wi-fi network with SSID '$2' not found."
        exit 4
    fi
    ((try++))
    echo "Scan failed, retrying... (${try}/${SCAN_RETRY})"
    sleep ${SCAN_INTERVAL}
done

# wpa_supplicantが動いていたら殺す
pkill -f "wpa_supplicant.+-i *$1 .*"

# SSIDを設定
iwconfig $1 essid $2

# WPA認証タイムアウト秒数
WPA_AUTH_TIMEOUT=20
is_connected=false
current_time=$(date +%s)
# wpa_supplicantをnohupで起動し接続。stdbufはバッファリングを防止するために必要
while read -t ${WPA_AUTH_TIMEOUT} line; do
    echo "  $line"
    echo $line | grep -wq 'CTRL-EVENT-CONNECTED'
    if [ $? -eq 0 ]; then
        is_connected=true
        break
    fi
    # タイムアウト判定
    if [ $(($(date +%s) - ${current_time})) -gt ${WPA_AUTH_TIMEOUT} ]; then
        echo "Timeout."
        break
    fi
done < <(nohup bash -c "wpa_passphrase $2 $3 | stdbuf -oL wpa_supplicant -B -i $1 -D wext -c /dev/stdin -f /dev/stdout")
# done < <(nohup bash -c "wpa_passphrase $2 $3 | stdbuf -oL wpa_supplicant -i $1 -D wext -c /dev/stdin 2>&1 | stdbuf -oL tee wpa.log &")
if ! $is_connected; then
    echo 'WPA authentication failed.'
    pkill -f "wpa_supplicant.+-i *$1 .*"
    exit 5
fi

# IPアドレス割り当て
ifconfig $1 | grep -q 'inet addr'
if [ $? -ne 0 ]; then
    dhclient $1
    ifconfig $1 | grep -q 'inet addr'
    if [ $? -ne 0 ]; then
        echo 'IP address cannot not be assgined.'
        exit 6
    fi
fi

echo 'Connected successfully.'
exit 0
