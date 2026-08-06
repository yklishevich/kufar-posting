import SwiftUI
import PostingData
import PostingDomain
import PostingUI
import PostingInterface
import CatalogContracts
import AnalyticsAPI
import Networking

/// Единственный продукт пакета.
public enum PostingAssembly {

    public static func makeRepository(client: APIClient) -> any PostingRepository {
        RemotePostingRepository(client: client)
    }

    public static func makeDraftStore() -> any DraftStore {
        FileDraftStore()
    }

    /// `Step` наружу не течёт: его прячет `some ViewModifier`. Композиционный
    /// корень передаёт замыкание и никогда не называет получившийся тип —
    /// `PostingDestinations<_ConditionalContent<…>>` не написан нигде.
    public static func makeDestinations<Step: View>(
        repo: any PostingRepository,
        drafts: any DraftStore,
        analytics: any AnalyticsTracking,
        @ViewBuilder step: @escaping (CatalogCategory, Binding<PostingDraft>) -> Step
    ) -> some ViewModifier {
        PostingDestinations(repo: repo, drafts: drafts, analytics: analytics, step: step)
    }

    @MainActor
    public static func makeEntryScreen(
        repo: any PostingRepository,
        drafts: any DraftStore,
        analytics: any AnalyticsTracking
    ) -> some View {
        PostingCategoryScreen(repo: repo, drafts: drafts, analytics: analytics)
    }
}
