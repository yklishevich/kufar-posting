import SwiftUI
import PostingData
import PostingDomain
import PostingUI
import PostingInterface
import CatalogContracts
import AnalyticsAPI
import NetworkingInterface

/// The package's only product.
public enum PostingAssembly {

    public static func makeRepository(client: any HTTPPerforming) -> any PostingRepository {
        RemotePostingRepository(client: client)
    }

    public static func makeDraftStore() -> any DraftStore {
        FileDraftStore()
    }

    /// `Step` does not leak outwards: `some ViewModifier` hides it. The
    /// composition root passes a closure and never names the resulting type —
    /// `PostingDestinations<_ConditionalContent<…>>` is written nowhere.
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
