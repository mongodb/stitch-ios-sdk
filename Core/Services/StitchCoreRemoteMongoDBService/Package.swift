// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreRemoteMongoDBService",
    products: [
        .library(
            name: "StitchCoreRemoteMongoDBService",
            targets: ["StitchCoreRemoteMongoDBService"])
    ],
    dependencies: [
        .package(url: "../../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreRemoteMongoDBService",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreRemoteMongoDBServiceTests",
            dependencies: ["StitchCoreRemoteMongoDBService", "StitchCoreSDKMocks"])
    ]
)
