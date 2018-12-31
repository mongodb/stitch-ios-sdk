// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "MockUtils",
    products: [
        .library(
            name: "MockUtils",
            targets: ["MockUtils"])
    ],
    dependencies: [ ],
    targets: [
        .target(
            name: "MockUtils",
            dependencies: []),
        .testTarget(
            name: "MockUtilsTests",
            dependencies: ["MockUtils"])
    ]
)
