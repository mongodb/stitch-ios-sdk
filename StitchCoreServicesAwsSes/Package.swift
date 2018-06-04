// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreServicesAwsSes",
    products: [
        .library(
            name: "StitchCoreServicesAwsSes",
            targets: ["StitchCoreServicesAwsSes"]),
    ],
    dependencies: [
        .package(url: "../StitchCore", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreServicesAwsSes",
            dependencies: ["StitchCore"]),
        .testTarget(
            name: "StitchCoreServicesAwsSesTests",
            dependencies: ["StitchCoreServicesAwsSes", "StitchCoreMocks"]),
    ]
)
