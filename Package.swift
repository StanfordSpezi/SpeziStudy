// swift-tools-version:6.0

//
// This source file is part of the Stanford Spezi open source project
// 
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import class Foundation.ProcessInfo
import PackageDescription


let package = Package(
    name: "SpeziStudy",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "SpeziStudy", targets: ["SpeziStudy"]),
        .library(name: "SpeziStudyDefinition", targets: ["SpeziStudyDefinition"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/FHIRModels", .upToNextMinor(from: "0.5.0")),
        .package(url: "https://github.com/StanfordSpezi/SpeziHealthKit.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/StanfordSpezi/SpeziScheduler.git", branch: "lukas/improve-task-creation"),
        .package(url: "https://github.com/StanfordSpezi/SpeziStorage.git", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4")
    ] + swiftLintPackage(),
    targets: [
        .target(
            name: "SpeziStudyDefinition",
            dependencies: [
                .product(name: "ModelsR4", package: "FHIRModels"),
                .product(name: "SpeziHealthKit", package: "SpeziHealthKit"),
                .product(name: "SpeziScheduler", package: "SpeziScheduler"),
                .product(name: "DequeModule", package: "swift-collections")
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "SpeziStudy",
            dependencies: [
                .target(name: "SpeziStudyDefinition"),
                .product(name: "ModelsR4", package: "FHIRModels"),
                .product(name: "SpeziHealthKit", package: "SpeziHealthKit"),
                .product(name: "SpeziLocalStorage", package: "SpeziStorage"),
                .product(name: "SpeziScheduler", package: "SpeziScheduler"),
                .product(name: "SpeziSchedulerUI", package: "SpeziScheduler")
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziStudyTests",
            dependencies: [
                .target(name: "SpeziStudy"),
                .target(name: "SpeziStudyDefinition"),
                .product(name: "ModelsR4", package: "FHIRModels")
            ],
            resources: [.process("Resources")],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
            plugins: [] + swiftLintPlugin()
        )
    ]
)


func swiftLintPlugin() -> [Target.PluginUsage] {
    // Fully quit Xcode and open again with `open --env SPEZI_DEVELOPMENT_SWIFTLINT /Applications/Xcode.app`
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
    } else {
        []
    }
}

func swiftLintPackage() -> [PackageDescription.Package.Dependency] {
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.package(url: "https://github.com/realm/SwiftLint.git", from: "0.55.1")]
    } else {
        []
    }
}
