// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "StitchCoreSDK",
    products: [
        .library(
            name: "StitchCoreSDK",
            targets: ["StitchCoreSDK"]),
        .library(
            name: "StitchCoreSDKMocks",
            targets: ["StitchCoreSDKMocks"])
    ],
    dependencies: [
        .package(url: "../../MockUtils", .branch("master")),
        .package(url: "https://github.com/httpswift/swifter.git", .upToNextMajor(from: "1.4.0")),
        .package(url: "https://github.com/kylef/JSONWebToken.swift.git", .upToNextMajor(from: "2.2.0"))
    ],
    targets: [
        .target(
            name: "StitchCoreSDK",
            dependencies: []),
        .target(
            name: "StitchCoreSDKMocks",
            dependencies: ["StitchCoreSDK", "MockUtils"]),
        .testTarget(
            name: "StitchCoreSDKTests",
            dependencies: ["Swifter", "JWT", "StitchCoreSDK", "StitchCoreSDKMocks"])
    ]
)
