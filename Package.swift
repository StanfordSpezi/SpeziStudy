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
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "SpeziStudy", targets: ["SpeziStudy"]),
        .library(name: "SpeziStudyDefinition", targets: ["SpeziStudyDefinition"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/FHIRModels.git", from: "0.7.0"),
        .package(url: "https://github.com/StanfordSpezi/Spezi.git", from: "1.8.1"),
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation.git", from: "2.4.2"),
        .package(url: "https://github.com/StanfordSpezi/SpeziHealthKit.git", from: "1.1.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziScheduler.git", from: "1.2.14"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNotifications.git", from: "1.0.8"),
        .package(url: "https://github.com/StanfordSpezi/SpeziStorage.git", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4")
    ] + swiftLintPackage(),
    targets: [
        .target(
            name: "SpeziStudyDefinition",
            dependencies: [
                .product(name: "ModelsR4", package: "FHIRModels"),
                .product(name: "SpeziHealthKit", package: "SpeziHealthKit"),
                .product(name: "SpeziHealthKitBulkExport", package: "SpeziHealthKit"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "SpeziLocalization", package: "SpeziFoundation"),
                .product(name: "SpeziScheduler", package: "SpeziScheduler"),
                .product(name: "DequeModule", package: "swift-collections")
            ],
            resources: [.process("Resources")],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "SpeziStudy",
            dependencies: [
                .target(name: "SpeziStudyDefinition"),
                .product(name: "Spezi", package: "Spezi"),
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
                .product(name: "SpeziTesting", package: "Spezi"),
                .product(name: "ModelsR4", package: "FHIRModels")
            ],
            resources: [.process("Resources/questionnaires"), .copy("Resources/assets")],
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
