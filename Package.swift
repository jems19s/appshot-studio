// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "appshot-studio",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/tayloraswift/swift-png", from: "4.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "appshot",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "PNG", package: "swift-png"),
            ]
        ),
        .testTarget(
            name: "appshotTests",
            dependencies: [
                "appshot",
                .product(name: "PNG", package: "swift-png"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
