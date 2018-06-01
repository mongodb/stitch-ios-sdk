// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreServicesTwilio",
    products: [
        .library(
            name: "StitchCoreServicesTwilio",
            targets: ["StitchCoreServicesTwilio"]),
    ],
    dependencies: [
        .package(url: "../StitchCore", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreServicesTwilio",
            dependencies: ["StitchCore"]),
        .testTarget(
            name: "StitchCoreServicesTwilioTests",
            dependencies: ["StitchCoreServicesTwilio", "StitchCoreMocks"]),
    ]
)
