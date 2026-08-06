import Foundation
import SharedKernel
import PostingInterface
import CatalogContracts

/// Результат публикации: ссылка на созданное объявление.
/// Вертикаль приезжает данными — её определил бэкенд по категории.
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
    /// Схема формы для категории — тот же механизм, что у фильтров,
    /// только поля редактируемые и обязательные помечены.
    func formSchema(categoryID: CatalogCategory.ID) async throws -> Data
    func publish(_ draft: PostingDraft) async throws -> PublishedListing
}

/// Хранилище черновика. Отдельный протокол, потому что у него другая
/// природа: репозиторий ходит в сеть, черновик живёт на диске и должен
/// переживать краш.
public protocol DraftStore: Sendable {
    func load() async -> PostingDraft?
    func save(_ draft: PostingDraft) async
    func clear() async
}
