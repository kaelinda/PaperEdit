// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "PaperEditApp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "PaperEditApp", targets: ["PaperEditApp"]),
        .executable(name: "paper", targets: ["paper"]),
    ],
    targets: [
        .executableTarget(
            name: "PaperEditApp"
        ),
        .executableTarget(
            name: "paper"
        ),
        .testTarget(
            name: "PaperEditAppTests",
            dependencies: ["PaperEditApp"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
