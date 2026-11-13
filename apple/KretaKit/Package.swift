// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KretaKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "KretaKit", targets: ["KretaKit"])
    ],
    targets: [
        .target(name: "KretaKit"),
        .testTarget(name: "KretaKitTests", dependencies: ["KretaKit"])
    ]
)
