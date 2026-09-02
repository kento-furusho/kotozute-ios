#!/bin/bash
# 実機向けにビルドして、インストール・起動まで行う。
#
#   ./scripts/build-device.sh                       ペアリング済みの端末が1台ならそれに入れる
#   ./scripts/build-device.sh --device <名前かID>    端末を指定する（2台テストのとき）
#   ./scripts/build-device.sh --list                ペアリング済みの端末を並べる
#   ./scripts/build-device.sh --device ゆい --demo-state locked
#                                                   起動引数はそのまま渡る（DEBUGのみ）
#
# シミュレータ版との違いは署名まわり。実機は必ず署名が要るので、
# -allowProvisioningUpdates で Xcode に端末の登録とプロファイルの作り直しを任せる。
# 2台目を初めて繋いだときは、ここで自動的にポータルへ登録される。
#
# これは Debug ビルドなので aps-environment は development。
# 通知は SNS の sandbox 側プラットフォームアプリを通る（端末が apnsEnvironment を送り、
# サーバーが宛先を選ぶ）。配布ビルドの通知を試すには TestFlight が要る。
set -uo pipefail

BUNDLE_ID="dev.kotozute.app"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/kotozute-ios"
APP="$DERIVED/Build/Products/Debug-iphoneos/Kotozute.app"

cd "$(dirname "$0")/.."

devices() { xcrun devicectl list devices 2>/dev/null | grep "available"; }

if [[ "${1:-}" == "--list" ]]; then
  xcrun devicectl list devices
  exit 0
fi

DEVICE=""
if [[ "${1:-}" == "--device" ]]; then
  DEVICE="$2"
  shift 2
fi

# 端末の指定が無ければ、繋がっているものが1台のときだけ黙って選ぶ。
# 2台あるのに黙って選ぶと、どちらに入ったのか分からないまま検証することになる。
if [[ -z "$DEVICE" ]]; then
  count=$(devices | wc -l | tr -d ' ')
  if [[ "$count" == "1" ]]; then
    DEVICE=$(devices | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
  else
    echo "端末を --device で指定する（$count 台つながっている）"
    xcrun devicectl list devices
    exit 1
  fi
fi

# 名前で指定されたら ID に直す。
if [[ ! "$DEVICE" =~ ^[0-9A-F-]{36}$ ]]; then
  RESOLVED=$(devices | grep -i "$DEVICE" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
  if [[ -z "$RESOLVED" ]]; then
    echo "端末が見つからない: $DEVICE"
    xcrun devicectl list devices
    exit 1
  fi
  DEVICE="$RESOLVED"
fi

# project.yml が正、.xcodeproj は生成物。
xcodegen generate >/dev/null

if ! xcodebuild -project Kotozute.xcodeproj -scheme Kotozute \
  -destination "platform=iOS,id=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  -skipPackagePluginValidation -skipMacroValidation \
  build > /tmp/kotozute-device-build.log 2>&1; then
  grep -E "error:" /tmp/kotozute-device-build.log | sort -u | head -20
  echo "ビルド失敗（詳細は /tmp/kotozute-device-build.log）"
  exit 1
fi

echo "ビルド成功"

xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null || exit 1
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" "$@"
