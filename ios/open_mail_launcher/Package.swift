// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "open_mail_launcher",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "open_mail_launcher", targets: ["open_mail_launcher"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "open_mail_launcher",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
) 