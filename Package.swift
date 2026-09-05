// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OrtholinearCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "OrtholinearCore", targets: ["OrtholinearCore"])],
    targets: [
        .target(name: "OrtholinearCore", path: "Core"),
        .testTarget(name: "OrtholinearCoreTests", dependencies: ["OrtholinearCore"], path: "Tests")
    ]
)
