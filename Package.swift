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
    dependencies: [ .package(name: "swift-docc-plugin", url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"), 
        .package(url: "https://github.com/jectivex/Jack.git", from: "2.0.0"),
        .package(url: "https://github.com/tiqtiq/TiqDB.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "SQLPod",
            dependencies: [
                .product(name: "Jack", package: "Jack"),
                .product(name: "TiqDB", package: "TiqDB"),
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "SQLPodTests",
            dependencies: ["SQLPod"]),
    ]
)
