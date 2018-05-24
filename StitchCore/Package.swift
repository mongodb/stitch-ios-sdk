// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCore",
    products: [
        .library(
            name: "StitchCore",
            targets: ["StitchCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", .branch("master")),
        .package(url: "https://github.com/httpswift/swifter.git", .upToNextMajor(from: "1.4.0")),
        .package(url: "https://github.com/kylef/JSONWebToken.swift.git", .upToNextMajor(from: "2.2.0"))
    ],
    targets: [
        .target(
            name: "StitchCore",
            dependencies: ["MongoSwift"]),
        .testTarget(
            name: "StitchCoreTests",
            dependencies: ["MongoSwift", "Swifter", "JWT", "StitchCore"])
    ]
)
