// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreHTTPService",
    products: [
        .library(
            name: "StitchCoreHTTPService",
            targets: ["StitchCoreHTTPService"]),
    ],
    dependencies: [
        .package(url: "../../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreHTTPService",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreHTTPServiceTests",
            dependencies: ["StitchCoreHTTPService", "StitchCoreSDKMocks"]),
    ]
)
