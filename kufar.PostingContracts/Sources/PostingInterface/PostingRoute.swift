import Foundation
import SharedKernel
import CatalogContracts

/// The posting contract. Data-only, Foundation.
public enum PostingRoute: Hashable, Codable, Sendable, CaseIterable {
    /// The category-picking step — the entry into the funnel.
    case category
    /// The form for the chosen category. The backend defines the set of fields.
    case form(CatalogCategory.ID)
    /// A draft restored after the app was closed.
    case draft(PostingDraft.ID)

    public static var allCases: [PostingRoute] {
        [.category, .form("sample"), .draft(PostingDraft.ID("sample"))]
    }
}

/// A listing draft.
///
/// Codable, because it survives the app being evicted from memory: posting is the
/// most conversion-sensitive place in the product, and a draft lost on step three
/// is a listing that never got created — that is, lost liquidity.
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
    /// schema field id → value. Exactly the same shape as the filter state.
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
