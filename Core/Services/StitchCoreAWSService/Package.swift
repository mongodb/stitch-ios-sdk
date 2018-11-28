// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreAWSService",
    products: [
        .library(
            name: "StitchCoreAWSService",
            targets: ["StitchCoreAWSService"])
    ],
    dependencies: [
        .package(url: "../../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreAWSService",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreAWSServiceTests",
            dependencies: ["StitchCoreAWSService", "StitchCoreSDKMocks"])
    ]
)
