import Foundation
import PostingDomain
import PostingInterface
import CatalogContracts
import NetworkingInterface
import SharedKernel

package struct RemotePostingRepository: PostingRepository {
    private let client: any HTTPPerforming

    package init(client: any HTTPPerforming) {
        self.client = client
    }

    package func categories() async throws -> [CatalogCategory] {
        _ = try? await client.get("catalog/categories")
        return Self.tree
    }

    package func formSchema(categoryID: CatalogCategory.ID) async throws -> Data {
        _ = try? await client.get("posting/\(categoryID)/form")
        return Self.schema(for: categoryID)
    }

    package func publish(_ draft: PostingDraft) async throws -> PublishedListing {
        guard draft.isPublishable else { throw PostingError.incomplete }
        _ = try? await client.get("posting/publish")
        try? await Task.sleep(for: .milliseconds(600))

        // The backend determines the vertical from the category — the client does not derive it.
        let vertical = Self.tree.find(draft.categoryID)?.vertical ?? .goods
        // A switch rather than a ternary: a new vertical has to stop the build
        // rather than silently pick up somebody else's prefix. In the demo this is
        // only a fixture id, but the shape of the mistake is the same as with the
        // badge in the feed.
        let prefix = switch vertical {
        case .goods: "g"
        case .auto: "a"
        }
        return PublishedListing(id: ListingID("\(prefix)-new"), vertical: vertical)
    }
}

/// The draft on disk. In a real project this would be a file in Application
/// Support plus incremental photo upload with resume.
package actor FileDraftStore: DraftStore {
    private var stored: PostingDraft?

    package init() {}

    package func load() async -> PostingDraft? { stored }
    package func save(_ draft: PostingDraft) async { stored = draft }
    package func clear() async { stored = nil }
}
