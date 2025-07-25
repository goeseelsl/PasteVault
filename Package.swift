// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "ClipboardManager", targets: ["ClipboardManager"])
    ],
    dependencies: [
        .package(name: "Sauce", url: "https://github.com/Clipy/Sauce", from: "2.4.1")
    ],
    targets: [
        .executableTarget(
            name: "ClipboardManager",
            dependencies: ["Sauce"],
            path: "ClipboardManager",
            exclude: ["Info.plist", "Resources"],
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content")
            ]
        )
    ]
)
