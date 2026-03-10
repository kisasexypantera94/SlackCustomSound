// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlackCustomSound",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SlackCustomSound",
            targets: ["SlackCustomSound"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SlackCustomSound",
            path: "Sources/SlackCustomSound"
        )
    ]
)
