// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreServicesTwilio",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "StitchCoreServicesTwilio",
            targets: ["StitchCoreServicesTwilio"]),
    ],
    dependencies: [
      // Dependencies declare other packages that this package depends on.
      // .package(url: /* package url */, from: "1.0.0"),
      .package(url: "https://github.com/mongodb/swift-bson", .branch("master")),
      .package(url: "../StitchCore", .branch("master")),
      .package(url: "https://github.com/jsflax/BSON", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "StitchCoreServicesTwilio",
            dependencies: ["libbson", "StitchCore", "BSON"]),
        .testTarget(
            name: "StitchCoreServicesTwilioTests",
            dependencies: ["StitchCoreServicesTwilio"]),
    ]
)
