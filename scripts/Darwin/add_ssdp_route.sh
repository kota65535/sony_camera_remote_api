#!/bin/bash
set -u
export LANG="C"

function usage() {
  cat <<EOT
Usage: bash ${0##*/} <interface-name>
EOT
}

# 引数チェック
if [ $# -ne 1 ]; then usage && exit 1; fi

# SSDP discoverで使用するブロードキャストアドレス
SSDP_ADDR=239.255.255.250

# 所定のインターフェース経由の経路があるか調べる
route get ${SSDP_ADDR} | grep -q "interface: $1"
if [ $? -eq 0 ]; then
  echo 'Route already configured.'
  exit 0
fi

# 所定のインターフェース経由の経路を追加する
route add -host ${SSDP_ADDR} -interface $1
if [ $? -ne 0 ]; then
  echo "Failed to add route to host ${SSDP_ADDR} via $1"
  exit 1
fi

# 最後に再度確認
route get ${SSDP_ADDR} | grep -q "interface: $1"
if [ $? -eq 0 ]; then
  echo "Something goes wrong!"
  exit 2
fi

echo 'Route added successfully.'
exit 0
