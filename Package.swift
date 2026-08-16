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
        .library(name: "KotozuteAPI", targets: ["KotozuteAPI"])
    ],
    targets: [
        .target(name: "KotozuteAPI"),
        .testTarget(name: "KotozuteAPITests", dependencies: ["KotozuteAPI"]),
    ]
)
