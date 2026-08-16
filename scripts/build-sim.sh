#!/bin/bash
# シミュレータ向けにビルドして、インストール・起動まで行う。
#
#   ./scripts/build-sim.sh                                  ビルドして起動
#   ./scripts/build-sim.sh --signin メール パスワード        起動時に自動サインイン（DEBUGのみ）
#   ./scripts/build-sim.sh --demo-state locked              通信せず画面だけ確認
#
# 署名について:
#   このリポジトリは ~/Documents 配下にあり iCloud Drive の同期対象。同期プロセスが
#   ビルド生成物に拡張属性（FinderInfo / fileprovider）を付け続け、codesign が
#   "detritus not allowed" で失敗する。消してもすぐ付け直されるため、
#   DerivedData を同期対象外（~/Library/Developer/Xcode/DerivedData）に置く。
set -uo pipefail

UDID="${KOTOZUTE_SIM_UDID:-6C33D43C-36C0-4DDF-B4E7-EB501C0BE006}"
BUNDLE_ID="dev.kotozute.app"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/kotozute-ios"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Kotozute.app"

cd "$(dirname "$0")/.."

# project.yml が正、.xcodeproj は生成物。
xcodegen generate >/dev/null

build() {
  xcodebuild -project Kotozute.xcodeproj -scheme Kotozute \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" \
    -skipPackagePluginValidation -skipMacroValidation \
    build > /tmp/kotozute-build.log 2>&1
}

if ! build; then
  grep -E "error:" /tmp/kotozute-build.log | sort -u | head -20
  echo "ビルド失敗（詳細は /tmp/kotozute-build.log）"
  exit 1
fi

echo "ビルド成功"

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@"
