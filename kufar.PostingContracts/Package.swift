// swift-tools-version: 5.9
import PackageDescription

// The posting contracts. They are used by the app root (the kufar://post deep
// link) and by the profile (the "Post a listing" button).

let package = Package(
    name: "KufarPostingContracts",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "PostingInterface", targets: ["PostingInterface"])
    ],
    dependencies: [
        .package(id: "kufar.Foundation", from: "1.0.0"),
        .package(id: "kufar.CatalogContracts", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "PostingInterface",
            dependencies: [
                .product(name: "SharedKernel", package: "kufar.Foundation"),
                .product(name: "CatalogContracts", package: "kufar.CatalogContracts")
            ]
        )
    ]
)
