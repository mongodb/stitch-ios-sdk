// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StitchCoreAdminClient",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "StitchCoreAdminClient",
            targets: ["StitchCoreAdminClient"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
      .package(url: "https://github.com/mongodb/swift-bson", .branch("master")),
      .package(url: "../StitchCore", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "StitchCoreAdminClient",
            dependencies: ["libbson", "StitchCore"]),
        .testTarget(
            name: "StitchCoreAdminClientTests",
            dependencies: ["StitchCoreAdminClient"]),
    ]
)
