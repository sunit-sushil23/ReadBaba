// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ReadBaba",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "ReadBaba",
            targets: ["ReadBaba"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ReadBaba",
            dependencies: [])
    ]
)
