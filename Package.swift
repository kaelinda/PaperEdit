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
            name: "PaperEditApp",
            swiftSettings: [
                .unsafeFlags(["-F", "ThirdParty"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-F", "ThirdParty", "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .executableTarget(
            name: "paper"
        ),
        .testTarget(
            name: "PaperEditAppTests",
            dependencies: ["PaperEditApp"],
            swiftSettings: [
                .unsafeFlags(["-F", "ThirdParty"]),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
