// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LoadingView",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "LoadingView",
            targets: ["LoadingView"]),
    ],
    targets: [
        .target(
            name: "LoadingView"
        ),
        .testTarget(
            name: "LoadingViewTests",
            dependencies: ["LoadingView"]),
    ]
)
