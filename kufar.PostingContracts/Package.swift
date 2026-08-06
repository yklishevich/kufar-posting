// swift-tools-version: 5.9
import PackageDescription

// Контракты подачи. Их берут корень приложения (диплинк kufar://post)
// и профиль (кнопка «Подать объявление»).

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
