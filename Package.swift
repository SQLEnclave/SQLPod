// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "SQLPod",
    products: [
        .library(
            name: "SQLPod",
            targets: ["SQLPod"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tiqtiq/TiqDB.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "SQLPod",
            dependencies: [
                .product(name: "TiqDB", package: "TiqDB"),
            ]),
        .testTarget(
            name: "SQLPodTests",
            dependencies: ["SQLPod"]),
    ]
)
