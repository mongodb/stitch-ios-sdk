// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreAWSS3Service",
    products: [
        .library(
            name: "StitchCoreAWSS3Service",
            targets: ["StitchCoreAWSS3Service"]),
    ],
    dependencies: [
        .package(url: "../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreAWSS3Service",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreAWSS3ServiceTests",
            dependencies: ["StitchCoreAWSS3Service", "StitchCoreSDKMocks"]),
    ]
)
