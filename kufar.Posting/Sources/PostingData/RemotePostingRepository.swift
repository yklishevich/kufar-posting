import Foundation
import PostingDomain
import PostingInterface
import CatalogContracts
import Networking
import SharedKernel

package struct RemotePostingRepository: PostingRepository {
    private let client: APIClient

    package init(client: APIClient) {
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

        // Вертикаль определяет бэкенд по категории — клиент её не выводит.
        let vertical = Self.tree.find(draft.categoryID)?.vertical ?? .goods
        // switch, а не тернарник: новая вертикаль должна остановить сборку,
        // а не тихо получить чужой префикс. В демо это всего лишь id фикстуры,
        // но форма ошибки та же, что у бейджа в ленте.
        let prefix = switch vertical {
        case .goods: "g"
        case .auto: "a"
        }
        return PublishedListing(id: ListingID("\(prefix)-new"), vertical: vertical)
    }
}

/// Черновик на диске. В настоящем проекте — файл в Application Support
/// плюс инкрементальная выгрузка фотографий с докачкой.
package actor FileDraftStore: DraftStore {
    private var stored: PostingDraft?

    package init() {}

    package func load() async -> PostingDraft? { stored }
    package func save(_ draft: PostingDraft) async { stored = draft }
    package func clear() async { stored = nil }
}
