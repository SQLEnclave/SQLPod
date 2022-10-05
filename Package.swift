// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "SQLPod",
    platforms: [ .macOS(.v12), .iOS(.v15), .tvOS(.v15) ],
    products: [
        .library(
            name: "SQLPod",
            targets: ["SQLPod"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jectivex/Jack.git", from: "2.0.0"),
        .package(url: "https://github.com/sqlenclave/SQLEnclave.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "SQLPod",
            dependencies: [
                .product(name: "Jack", package: "Jack"),
                .product(name: "SQLEnclave", package: "SQLEnclave"),
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "SQLPodTests",
            dependencies: ["SQLPod"]),
    ]
)
