// swift-tools-version:4.0
import PackageDescription
let package = Package(
    name: "libmongoc",
    pkgConfig: "libmongoc-1.0",
    providers: [
        .brew(["mongo-c-driver"]),
        .apt(["libmongoc-dev"])
    ],
    products: [
        .library(name: "libmongoc", targets: ["libmongoc"])
    ]
)
