# ことづて iOS

ことづての iOS クライアント。バックエンドは別リポジトリ（`kotozute`／AWS SAM + Go）。

仕様の正は `kotozute` リポジトリの `docs/ios-kickoff.md` と `CLAUDE.md`。

## 現在の構成

```
KotozuteAPI/            Swift Package
  Sources/KotozuteAPI/  API 層（依存ゼロ。シミュレータ無しでテストできる）
  Sources/KotozuteAuth/ 認証層（Cognito。aws-sdk-swift に依存）
  Tests/
App/                    SwiftUI アプリ
project.yml             XcodeGen の定義（.xcodeproj は生成物）
scripts/build-sim.sh    ビルド〜シミュレータ起動
```

API 層と認証層を分けているのは、API 層の依存をゼロに保つため。
`swift test` が数秒で終わり、Cognito を持ち込まずにロジックを検証できる。

```bash
cd KotozuteAPI && swift test          # 通信しないテスト
./scripts/build-sim.sh                # ビルドしてシミュレータで起動
```

実際の Cognito と API に繋ぐテストは既定で走らない。

```bash
cd KotozuteAPI && KOTOZUTE_E2E=1 swift test --filter CognitoIntegrationTests
```

## バックエンドの接続先

デプロイ済み（`ap-northeast-1`）。

| 値 | |
|---|---|
| API ベースURL | `https://fce7tbbiq5.execute-api.ap-northeast-1.amazonaws.com/Prod` |
| UserPoolId | `ap-northeast-1_4mx0ifrEZ` |
| UserPoolClientId | `1hbuhnvdap6ah8e9tcs5elnuq` |
| リージョン | `ap-northeast-1` |

これらは秘密情報ではない。iOS のような公開クライアントはシークレットを持てない
（アプリに埋め込んだ値は逆コンパイルで取り出せる）ため、Cognito のクライアントも
シークレット無しで作ってある。アクセス制御はトークンの検証で行う。

## 認証

Amplify は使わず、素の AWS SDK for Swift で `InitiateAuth` を直接叩く（バックエンドの方針に合わせている）。

認証フローは **`USER_PASSWORD_AUTH`**。SDK に SRP のヘルパーが無く、SRP を使うには
プロトコル自体（大きな整数の冪剰余・HKDF など）を自前で実装する必要があるため。
パスワードは TLS 上で Cognito に送られる。SRP に差し替えるときは `CognitoAuthenticator`
の中だけで閉じる。

トークンは Keychain に置く。リフレッシュトークンは「持っていれば本人になりすませる」
値なので、バックアップやファイル閲覧から平文で読めてはいけない。

`CognitoAuthenticator` は `TokenProvider` に準拠しているので、`KotozuteClient` は
トークンの出所が Cognito であることを知らない。

## 実装上の注意

### 日時が2種類ある

| フィールド | 形式 | 型 |
|---|---|---|
| `createdAt` / `expiresAt` | RFC3339（`2026-08-11T12:00:00Z`） | `Date` |
| `nextOpenAt` | `2026-08-14T20:00`（秒・タイムゾーン無し） | `WallClock` |

`nextOpenAt` は絶対時刻ではなく「ペアのタイムゾーンでの壁時計」。`Date` にするには
`GET /pair` の `timezone` を渡す必要がある。標準の ISO8601 デコーダでは扱えない。

ペア未成立のとき `nextOpenAt` は省略ではなく空文字 `""` で返る。

### 相互ロックはサーバーが判定済み

`GET /kotozute/this-week` の `canSeePartner` が false のとき、`partnerKotozute` は
**キーごと返ってこない**。クライアントで隠すのではなく、そもそも本文が届かない。

`HomeState` はこのレスポンスを画面の分岐に翻訳するだけで、見せてよいかの判断を上書きしない。

### 気配表示

`partnerHasWritten` は 0枚か1枚以上かのみ。枚数は返らない。
相手が0枚の週は気配・ロック要素を一切出さない（「まだ書いてない」と読める表示を出さない）。

## 用語

- **ことづて** — 書いたメッセージ1つ1つ（単複同表記）
- **オープン** — 週に一度、相手のことづてが見られるようになること／その日

「開封」「めくる」「届く」は使わない。
