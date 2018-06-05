// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreServicesAwsS3",
    products: [
        .library(
            name: "StitchCoreServicesAwsS3",
            targets: ["StitchCoreServicesAwsS3"]),
    ],
    dependencies: [
        .package(url: "../StitchCore", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreServicesAwsS3",
            dependencies: ["StitchCore"]),
        .testTarget(
            name: "StitchCoreServicesAwsS3Tests",
            dependencies: ["StitchCoreServicesAwsS3", "StitchCoreMocks"]),
    ]
)
