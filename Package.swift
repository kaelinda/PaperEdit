// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "PaperEditApp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "PaperEditApp", targets: ["PaperEditApp"]),
    ],
    targets: [
        .executableTarget(
            name: "PaperEditApp"
        ),
        .testTarget(
            name: "PaperEditAppTests",
            dependencies: ["PaperEditApp"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
