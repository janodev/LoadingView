// swift-tools-version: 5.9

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
