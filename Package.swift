// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DemusRedesign",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "DemusRedesign",
            targets: ["DemusRedesign"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DemusRedesign",
            dependencies: [],
            path: "Sources/DemusRedesign"
        ),
        .testTarget(
            name: "DemusRedesignTests",
            dependencies: ["DemusRedesign"],
            path: "Tests/DemusRedesignTests"
        )
    ]
)
