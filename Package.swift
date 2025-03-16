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
        .watchOS(.v11),
        .visionOS(.v2),
        .tvOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "SpeziStudy", targets: ["SpeziStudy"]),
        .library(name: "SpeziStudyDefinition", targets: ["SpeziStudyDefinition"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/FHIRModels", .upToNextMinor(from: "0.5.0")),
        .package(url: "https://github.com/StanfordSpezi/SpeziHealthKit.git", exact: "1.0.0-beta.4"),
//        .package(url: "https://github.com/StanfordSpezi/SpeziQuestionnaire.git", from: "1.2.3"),
        .package(url: "https://github.com/StanfordSpezi/SpeziScheduler", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4"),
        .package(url: "https://github.com/StanfordSpezi/SpeziViews.git", from: "1.9.1"),
        .package(url: "https://github.com/StanfordSpezi/SpeziFirebase.git", from: "2.0.4"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.9.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziAccount.git", from: "2.1.3"),
        .package(url: "https://github.com/StanfordBDHG/HealthKitOnFHIR.git", .upToNextMinor(from: "0.2.13"))
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
                .product(name: "SpeziScheduler", package: "SpeziScheduler"),
                .product(name: "SpeziSchedulerUI", package: "SpeziScheduler"),
                .product(name: "SpeziViews", package: "SpeziViews"),
                .product(name: "SpeziAccount", package: "SpeziAccount"),
                .product(name: "SpeziFirebaseAccount", package: "SpeziFirebase"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "HealthKitOnFHIR", package: "HealthKitOnFHIR")
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziStudyTests",
            dependencies: [
                .target(name: "SpeziStudy")
            ],
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
