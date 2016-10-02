#!/bin/bash
set -u
export LANG="C"

function usage() {
  cat <<EOT
Usage: bash ${0##*/} <network-SSID> <password>
EOT
}

# 引数チェック
if [ $# -ne 2 ]; then usage && exit 1; fi

# Wi-Fiのデバイス名を調べる
WIFI_DEV_NAME=$(networksetup -listallhardwareports | grep -w Wi-Fi -A1 | awk '/^Device:/{ print $2 }')
if [ -z "${WIFI_DEV_NAME}" ]; then
  echo "Wi-Fi device not found!"
  exit 2
fi

# すでに接続されていれば終了
networksetup -getairportnetwork ${WIFI_DEV_NAME} | grep -wq $1
if [ $? -eq 0 ]; then
  echo 'Already connected.'
  exit 0
fi

POWER_ON_WAIT=1
# Wi-Fiの電源が入ってなければ入れる
networksetup -getairportpower ${WIFI_DEV_NAME} | grep -wiq 'off'
if [ $? -eq 0 ]; then
  networksetup -setairportpower ${WIFI_DEV_NAME} on
  if [ $? -ne 0 ]; then
    echo "Failed to power on ${WIFI_DEV_NAME}."
    exit 3
  fi
  sleep ${POWER_ON_WAIT}
fi

# airportコマンドのフルパス
AIRPORT_CMD='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport'
# 指定のSSIDを持つアクセスポイントがあるか調べる
${AIRPORT_CMD} --scan=$1 | grep -wq $1
if [ $? -ne 0 ]; then
  echo "The wi-fi network with SSID:'$1' not found."
  exit 4
fi

# 接続リトライ回数/リトライ間隔秒数
CONNECTION_RETRY=3
RETRY_INTERNAL=2
# 接続する
remain=${CONNECTION_RETRY}
while [ ${remain} -gt  0 ]
do
  # networksetup -setairportnetwork は成功時も失敗時も0を返してくるので出力で判断
  networksetup -setairportnetwork ${WIFI_DEV_NAME} $1 $2 | grep -wq 'Error'
  if [ $? -ne 0 ]; then
    break
  fi
  ((remain--))
  sleep ${RETRY_INTERNAL}
done
if [ ${remain} -eq 0 ]; then
  echo "Failed to join the network. Password may be incorrect."
  exit 5
fi

# 接続されているか念のため確認
networksetup -getairportnetwork ${WIFI_DEV_NAME} | grep -wq $1
if [ $? -ne 0 ]; then
  echo 'Something wrong occured!'
  exit 6
fi

echo 'Connected successfully.'
exit 0
