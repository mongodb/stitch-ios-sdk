// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreTwilioService",
    products: [
        .library(
            name: "StitchCoreTwilioService",
            targets: ["StitchCoreTwilioService"]),
    ],
    dependencies: [
        .package(url: "../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreTwilioService",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreTwilioServiceTests",
            dependencies: ["StitchCoreTwilioService", "StitchCoreSDKMocks"]),
    ]
)
