// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreAWSSESService",
    products: [
        .library(
            name: "StitchCoreAWSSESService",
            targets: ["StitchCoreAWSSESService"]),
    ],
    dependencies: [
        .package(url: "../StitchCoreSDK", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreAWSSESService",
            dependencies: ["StitchCoreSDK"]),
        .testTarget(
            name: "StitchCoreAWSSESServiceTests",
            dependencies: ["StitchCoreAWSSESService", "StitchCoreSDKMocks"]),
    ]
)
