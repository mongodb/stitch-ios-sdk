// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreServicesMongoDbRemote",
    products: [
        .library(
            name: "StitchCoreServicesMongoDbRemote",
            targets: ["StitchCoreServicesMongoDbRemote"]),
    ],
    dependencies: [
        .package(url: "../StitchCore", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreServicesMongoDbRemote",
            dependencies: ["StitchCore"]),
        .testTarget(
            name: "StitchCoreServicesMongoDbRemoteTests",
            dependencies: ["StitchCoreServicesMongoDbRemote", "StitchCoreMocks"]),
    ]
)
