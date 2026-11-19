// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CourseBoard",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "CourseBoard", targets: ["CourseBoard"])
    ],
    targets: [
        .target(
            name: "CourseBoardCore"
        ),
        .executableTarget(
            name: "CourseBoard",
            dependencies: ["CourseBoardCore"],
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "CourseBoardCoreTests",
            dependencies: ["CourseBoardCore"]
        )
    ]
)
