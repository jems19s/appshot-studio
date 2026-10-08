// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "appshot-studio",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "appshot", targets: ["appshot"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "appshot",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "appshotTests",
            dependencies: ["appshot"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
