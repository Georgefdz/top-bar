// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TopBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MenuBarClientShim", path: "Sources/MenuBarClientShim"),
        .executableTarget(name: "TopBar", dependencies: ["MenuBarClientShim"], path: "Sources/TopBar"),
        .testTarget(name: "TopBarTests", dependencies: ["TopBar"], path: "Tests/TopBarTests"),
    ]
)
