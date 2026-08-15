// swift-tools-version: 5.9
import PackageDescription

// The graph's second convergence point after search.
//
// Search reads across verticals, posting writes into one — but both know about
// every vertical at once and both know only their contracts. The mechanisms are
// shared too: the category tree and the schema renderer, only the form is
// editable.
//
// Exactly one product, Posting, sticks out. PostingUI, PostingData and
// PostingDomain stay internal targets.

let package = Package(
    name: "KufarPosting",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Posting", targets: ["Posting"])
    ],
    dependencies: [
        .package(id: "kufar.PostingContracts", from: "1.0.0"),
        .package(id: "kufar.CatalogContracts", from: "1.0.0"),
        .package(id: "kufar.GoodsContracts", from: "1.0.0"),
        .package(id: "kufar.AutoContracts", from: "1.0.0"),
        .package(id: "kufar.Foundation", from: "1.0.0"),
        .package(id: "kufar.Navigation", from: "1.0.0"),
        .package(id: "kufar.Analytics", from: "1.0.0"),
        .package(id: "kufar.DesignTokens", from: "1.0.0"),
        .package(id: "kufar.DesignComponents", from: "1.0.0"),
        .package(id: "kufar.SchemaKit", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "PostingDomain",
            dependencies: [
                .product(name: "SharedKernel", package: "kufar.Foundation"),
                .product(name: "PostingInterface", package: "kufar.PostingContracts"),
                .product(name: "CatalogContracts", package: "kufar.CatalogContracts")
            ]
        ),
        .target(
            name: "PostingData",
            dependencies: [
                "PostingDomain",
                .product(name: "SharedKernel", package: "kufar.Foundation"),
                .product(name: "NetworkingInterface", package: "kufar.Foundation"),
                .product(name: "PostingInterface", package: "kufar.PostingContracts"),
                .product(name: "CatalogContracts", package: "kufar.CatalogContracts")
            ]
        ),
        .target(
            name: "PostingUI",
            dependencies: [
                "PostingDomain",
                .product(name: "PostingInterface", package: "kufar.PostingContracts"),
                .product(name: "CatalogContracts", package: "kufar.CatalogContracts"),
                .product(name: "GoodsInterface", package: "kufar.GoodsContracts"),
                .product(name: "AutoInterface", package: "kufar.AutoContracts"),
                .product(name: "SharedKernel", package: "kufar.Foundation"),
                .product(name: "Navigation", package: "kufar.Navigation"),
                .product(name: "AnalyticsAPI", package: "kufar.Analytics"),
                .product(name: "DesignTokens", package: "kufar.DesignTokens"),
                .product(name: "DesignComponents", package: "kufar.DesignComponents"),
                .product(name: "SchemaKit", package: "kufar.SchemaKit")
            ]
        ),
        .target(
            name: "Posting",
            dependencies: [
                "PostingUI", "PostingData", "PostingDomain",
                .product(name: "NetworkingInterface", package: "kufar.Foundation"),
                .product(name: "AnalyticsAPI", package: "kufar.Analytics"),
                // CatalogCategory and PostingDraft appear in the posting slot's signature.
                .product(name: "PostingInterface", package: "kufar.PostingContracts"),
                .product(name: "CatalogContracts", package: "kufar.CatalogContracts")
            ]
        )
    ]
)
