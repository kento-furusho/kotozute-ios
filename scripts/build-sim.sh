#!/bin/bash
# シミュレータ向けにビルドして、インストール・起動まで行う。
#
#   ./scripts/build-sim.sh                                  ビルドして起動
#   ./scripts/build-sim.sh --signin メール パスワード        起動時に自動サインイン（DEBUGのみ）
#   ./scripts/build-sim.sh --demo-state locked              通信せず画面だけ確認
#
# 署名について:
#   aws-sdk-swift のリソースバンドルをアプリへコピーする際、macOS が拡張属性
#   （com.apple.provenance）を付ける。codesign はこれを "detritus" として拒否するため、
#   1度目のビルドが署名で失敗する。属性を落として署名だけやり直せば通るので、
#   失敗したら一度だけ掃除して再実行する。
set -uo pipefail

UDID="${KOTOZUTE_SIM_UDID:-6C33D43C-36C0-4DDF-B4E7-EB501C0BE006}"
BUNDLE_ID="dev.kotozute.app"
DERIVED=".build-ios"
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
  if grep -q "detritus" /tmp/kotozute-build.log; then
    echo "署名で弾かれたので拡張属性を落として再試行する"
    xattr -cr "$APP" 2>/dev/null
    if ! build; then
      grep -E "error:" /tmp/kotozute-build.log | sort -u | head -20
      echo "ビルド失敗（詳細は /tmp/kotozute-build.log）"
      exit 1
    fi
  else
    grep -E "error:" /tmp/kotozute-build.log | sort -u | head -20
    echo "ビルド失敗（詳細は /tmp/kotozute-build.log）"
    exit 1
  fi
fi

echo "ビルド成功"

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@"
