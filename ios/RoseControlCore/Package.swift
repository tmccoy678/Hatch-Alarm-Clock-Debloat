// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RoseControlCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RoseControlCore", targets: ["RoseControlCore"]),
        .executable(name: "RoseBLEProbe", targets: ["RoseBLEProbe"]),
    ],
    targets: [
        .target(name: "RoseControlCore"),
        .executableTarget(name: "RoseBLEProbe", dependencies: ["RoseControlCore"]),
        .testTarget(name: "RoseControlCoreTests", dependencies: ["RoseControlCore"]),
    ]
)
