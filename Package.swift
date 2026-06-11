// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Murmur",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        )
    ]
)
