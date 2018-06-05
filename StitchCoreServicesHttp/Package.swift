// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreServicesHttp",
    products: [
        .library(
            name: "StitchCoreServicesHttp",
            targets: ["StitchCoreServicesHttp"]),
    ],
    dependencies: [
        .package(url: "../StitchCore", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreServicesHttp",
            dependencies: ["StitchCore"]),
        .testTarget(
            name: "StitchCoreServicesHttpTests",
            dependencies: ["StitchCoreServicesHttp", "StitchCoreMocks"]),
    ]
)
