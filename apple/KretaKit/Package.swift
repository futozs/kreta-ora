// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KretaKit",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "KretaKit", targets: ["KretaKit"])
    ],
    targets: [
        .target(name: "KretaKit"),
        .testTarget(name: "KretaKitTests", dependencies: ["KretaKit"])
    ]
)
