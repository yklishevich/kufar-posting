import Foundation
import SharedKernel
import CatalogContracts

/// Контракт подачи. Data-only, Foundation.
public enum PostingRoute: Hashable, Codable, Sendable, CaseIterable {
    /// Шаг выбора категории — вход в воронку.
    case category
    /// Форма для выбранной категории. Состав полей задаёт бэкенд.
    case form(CatalogCategory.ID)
    /// Черновик, восстановленный после закрытия приложения.
    case draft(PostingDraft.ID)

    public static var allCases: [PostingRoute] {
        [.category, .form("sample"), .draft(PostingDraft.ID("sample"))]
    }
}

/// Черновик объявления.
///
/// Codable, потому что переживает выгрузку приложения из памяти: подача —
/// самое конверсионное место продукта, и потерянный на третьем шаге черновик
/// это потерянное объявление, то есть потерянная ликвидность.
public struct PostingDraft: Identifiable, Hashable, Codable, Sendable {
    public struct ID: Hashable, Codable, Sendable, RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ value: String) { self.rawValue = value }
    }

    public let id: ID
    public var categoryID: CatalogCategory.ID?
    public var title: String
    public var price: Decimal?
    /// id поля схемы → значение. Ровно та же форма, что у состояния фильтра.
    public var values: [String: AttributeValue]
    public var photoCount: Int
    public var updatedAt: Date

    public init(
        id: ID = ID(UUID().uuidString),
        categoryID: CatalogCategory.ID? = nil,
        title: String = "",
        price: Decimal? = nil,
        values: [String: AttributeValue] = [:],
        photoCount: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.categoryID = categoryID
        self.title = title
        self.price = price
        self.values = values
        self.photoCount = photoCount
        self.updatedAt = updatedAt
    }

    public var isPublishable: Bool {
        categoryID != nil && !title.isEmpty && price != nil && photoCount > 0
    }
}
