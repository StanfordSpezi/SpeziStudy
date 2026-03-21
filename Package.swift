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
        .macCatalyst(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: products(),
    dependencies: dependencies() + swiftLintPackage(),
    targets: targets()
)


func products() -> [Product] {
    var products: [Product] = [
        .library(name: "SpeziStudyDefinition", targets: ["SpeziStudyDefinition"])
    ]
    #if canImport(Darwin)
    products.append(.library(name: "SpeziStudy", targets: ["SpeziStudy"]))
    #endif
    return products
}

func dependencies() -> [PackageDescription.Package.Dependency] {
    var dependencies: [PackageDescription.Package.Dependency] = [
        .package(url: "https://github.com/apple/FHIRModels.git", from: "0.8.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation.git", from: "2.7.4"),
        .package(url: "https://github.com/StanfordSpezi/SpeziHealthKit.git", from: "1.4.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziScheduler.git", from: "1.2.18"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2")
    ]
    #if canImport(Darwin)
    dependencies.append(contentsOf: [
        .package(url: "https://github.com/StanfordSpezi/Spezi.git", from: "1.10.1"),
        .package(url: "https://github.com/StanfordSpezi/SpeziStorage.git", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.1")
    ])
    #endif
    return dependencies
}

func targets() -> [Target] { // swiftlint:disable:this function_body_length
    var targets: [Target] = []

    let speziStudyDefinitionDependencies: [Target.Dependency] = [
        .product(name: "ModelsR4", package: "FHIRModels"),
        .product(name: "SpeziHealthKit", package: "SpeziHealthKit"),
        .product(name: "SpeziHealthKitBulkExport", package: "SpeziHealthKit"),
        .product(name: "SpeziFoundation", package: "SpeziFoundation"),
        .product(name: "SpeziLocalization", package: "SpeziFoundation"),
        .product(name: "SpeziScheduler", package: "SpeziScheduler"),
        .product(name: "DequeModule", package: "swift-collections"),
        .product(name: "Logging", package: "swift-log")
    ]
    targets.append(.target(
        name: "SpeziStudyDefinition",
        dependencies: speziStudyDefinitionDependencies,
        resources: [.process("Resources")],
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))

    #if canImport(Darwin)
    targets.append(.target(
        name: "SpeziStudy",
        dependencies: [
            .target(name: "SpeziStudyDefinition"),
            .product(name: "Spezi", package: "Spezi"),
            .product(name: "ModelsR4", package: "FHIRModels"),
            .product(name: "SpeziHealthKit", package: "SpeziHealthKit"),
            .product(name: "SpeziLocalStorage", package: "SpeziStorage"),
            .product(name: "SpeziScheduler", package: "SpeziScheduler"),
            .product(name: "SpeziSchedulerUI", package: "SpeziScheduler"),
            .product(name: "Algorithms", package: "swift-algorithms")
        ],
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))
    #endif

    var speziStudyTestsDependencies: [Target.Dependency] = [
        .target(name: "SpeziStudyDefinition"),
        .product(name: "ModelsR4", package: "FHIRModels")
    ]
    #if canImport(Darwin)
    speziStudyTestsDependencies.append(contentsOf: [
        .target(name: "SpeziStudy"),
        .product(name: "SpeziTesting", package: "Spezi")
    ])
    #endif
    targets.append(.testTarget(
        name: "SpeziStudyTests",
        dependencies: speziStudyTestsDependencies,
        resources: [.process("Resources/questionnaires"), .copy("Resources/assets")],
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))

    return targets
}


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
