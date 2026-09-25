// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Outbox",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Outbox",
            path: "Sources/Outbox",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
