// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreFCMService",
    products: [
        .library(
            name: "StitchCoreFCMService",
            targets: ["StitchCoreFCMService"]),
    ],
    dependencies: [
        .package(url: "../../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreFCMService",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreFCMServiceTests",
            dependencies: ["StitchCoreFCMService", "StitchCoreSDKMocks"]),
    ]
)
