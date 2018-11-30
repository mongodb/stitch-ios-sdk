// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreAdminClient",
    products: [
        .library(
            name: "StitchCoreAdminClient",
            targets: ["StitchCoreAdminClient"])
    ],
    dependencies: [
      .package(url: "../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreAdminClient",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreAdminClientTests",
            dependencies: ["StitchCoreAdminClient"])
    ]
)
