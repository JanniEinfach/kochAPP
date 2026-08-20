// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "CoreUtilities", targets: ["CoreUtilities"]),
        .library(name: "CoreUnits", targets: ["CoreUnits"]),
    ],
    targets: [
        .target(name: "CoreUtilities"),
        .target(name: "CoreUnits", dependencies: ["CoreUtilities"]),
        .testTarget(name: "CoreUnitsTests", dependencies: ["CoreUnits"]),
    ],
    swiftLanguageModes: [.v6]
)
