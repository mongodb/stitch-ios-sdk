// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCore",
    products: [
        .library(
            name: "StitchCore",
            targets: ["StitchCore"]),
        .library(
            name: "StitchCoreMocks",
            targets: ["StitchCoreMocks"])
    ],
    dependencies: [
        .package(url: "../MockUtils", .branch("master")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", .branch("master")),
        .package(url: "https://github.com/httpswift/swifter.git", .upToNextMajor(from: "1.4.0")),
        .package(url: "https://github.com/kylef/JSONWebToken.swift.git", .upToNextMajor(from: "2.2.0"))
    ],
    targets: [
        .target(
            name: "StitchCore",
            dependencies: ["MongoSwift"]),
        .target(
            name: "StitchCoreMocks",
            dependencies: ["StitchCore", "MockUtils"]),
        .testTarget(
            name: "StitchCoreTests",
            dependencies: ["MongoSwift", "Swifter", "JWT", "StitchCore", "StitchCoreMocks"])
    ]
)
