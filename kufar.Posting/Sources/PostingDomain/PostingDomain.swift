import Foundation
import SharedKernel
import PostingInterface
import CatalogContracts

/// The result of publishing: a link to the listing that was created.
/// The vertical arrives as data — the backend determined it from the category.
public struct PublishedListing: Hashable, Sendable {
    public let id: ListingID
    public let vertical: Vertical

    public init(id: ListingID, vertical: Vertical) {
        self.id = id
        self.vertical = vertical
    }
}

package enum PostingError: Error, Sendable {
    case incomplete
    case rejected(reason: String)
}

public protocol PostingRepository: Sendable {
    func categories() async throws -> [CatalogCategory]
    /// The form schema for a category — the same mechanism as the filters, only
    /// the fields are editable and the required ones are marked.
    func formSchema(categoryID: CatalogCategory.ID) async throws -> Data
    func publish(_ draft: PostingDraft) async throws -> PublishedListing
}

/// Draft storage. A separate protocol, because its nature is different: the
/// repository goes to the network, while the draft lives on disk and has to
/// survive a crash.
public protocol DraftStore: Sendable {
    func load() async -> PostingDraft?
    func save(_ draft: PostingDraft) async
    func clear() async
}
