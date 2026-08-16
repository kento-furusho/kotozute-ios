// swift-tools-version: 6.0
import PackageDescription

// ことづての API 層。UI から独立させ、シミュレータを起動せずに swift test で検証できるようにする。
// アプリ本体（SwiftUI）は後からこのパッケージを依存として取り込む。
let package = Package(
    name: "KotozuteAPI",
    platforms: [
        .iOS(.v17),
        // テストを macOS 上で直接走らせるために macOS も対象に含める。
        .macOS(.v14),
    ],
    products: [
        .library(name: "KotozuteAPI", targets: ["KotozuteAPI"]),
        .library(name: "KotozuteAuth", targets: ["KotozuteAuth"]),
    ],
    dependencies: [
        // Amplify は使わず素の AWS SDK を配線する方針（バックエンドと揃える）。
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.0.0")
    ],
    targets: [
        // API 層は依存ゼロに保つ。Cognito を混ぜるとテストが重くなる。
        .target(name: "KotozuteAPI"),
        .testTarget(name: "KotozuteAPITests", dependencies: ["KotozuteAPI"]),

        // 認証は別ターゲットに切り出し、API 層から Cognito を見えなくする。
        .target(
            name: "KotozuteAuth",
            dependencies: [
                "KotozuteAPI",
                .product(name: "AWSCognitoIdentityProvider", package: "aws-sdk-swift"),
            ]
        ),
        .testTarget(name: "KotozuteAuthTests", dependencies: ["KotozuteAuth"]),
    ]
)
