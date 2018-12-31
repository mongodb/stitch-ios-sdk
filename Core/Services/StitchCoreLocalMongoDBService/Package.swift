// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreLocalMongoDBService",
    products: [
        .library(
            name: "StitchCoreLocalMongoDBService",
            targets: ["StitchCoreLocalMongoDBService"])
    ],
    dependencies: [
        .package(url: "../../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreLocalMongoDBService",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreLocalMongoDBServiceTests",
            dependencies: ["StitchCoreLocalMongoDBService"])
    ]
)
