// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LoadingView",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LoadingView",
            targets: ["LoadingView"]),
    ],
    targets: [
        .target(
            name: "LoadingView"),
        .testTarget(
            name: "LoadingViewTests",
            dependencies: ["LoadingView"]),
    ]
)
