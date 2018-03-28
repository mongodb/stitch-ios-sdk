// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCore",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "StitchCore",
            targets: ["StitchCore"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/jsflax/ExtendedJSON", .branch("master")),
        .package(url: "https://github.com/httpswift/swifter.git", .upToNextMajor(from: "1.4.0")),
        .package(url: "https://github.com/kylef/JSONWebToken.swift.git", .upToNextMajor(from: "2.2.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package
        // depends on.
        .target(
            name: "StitchCore",
            dependencies: ["ExtendedJSON"]),
        .testTarget(
            name: "stitch-ios-sdk-protoTests",
            dependencies: ["StitchCore", "ExtendedJSON", "Swifter", "JWT"])
    ]
)
