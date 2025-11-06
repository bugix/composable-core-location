// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "composable-core-location",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "ComposableCoreLocation",
            targets: ["ComposableCoreLocation"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ComposableCoreLocation",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "ComposableCoreLocationTests",
            dependencies: ["ComposableCoreLocation"]
        ),
    ]
)
