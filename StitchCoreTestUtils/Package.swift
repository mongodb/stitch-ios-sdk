// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "StitchCoreTestUtils",
    products: [
        .library(
            name: "StitchCoreTestUtils",
            targets: ["StitchCoreTestUtils"]),
    ],
    dependencies: [
      .package(url: "../StitchCoreAdminClient", .branch("master"))
    ],
    targets: [
        .target(
            name: "StitchCoreTestUtils",
            dependencies: ["StitchCoreAdminClient"]),
        .testTarget(
            name: "StitchCoreTestUtilsTests",
            dependencies: ["StitchCoreTestUtils"]),
    ]
)
