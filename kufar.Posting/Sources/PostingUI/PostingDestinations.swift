import SwiftUI
import PostingDomain
import PostingInterface
import CatalogContracts
import AnalyticsAPI

package struct PostingDestinations<Step: View>: ViewModifier {
    private let repo: any PostingRepository
    private let drafts: any DraftStore
    private let analytics: any AnalyticsTracking
    private let step: (CatalogCategory, Binding<PostingDraft>) -> Step

    package init(repo: any PostingRepository,
                 drafts: any DraftStore,
                 analytics: any AnalyticsTracking,
                 @ViewBuilder step: @escaping (CatalogCategory, Binding<PostingDraft>) -> Step) {
        self.repo = repo
        self.drafts = drafts
        self.analytics = analytics
        self.step = step
    }

    package func body(content: Content) -> some View {
        content.navigationDestination(for: PostingRoute.self) { route in
            switch route {
            case .category:
                PostingCategoryScreen(repo: repo, drafts: drafts, analytics: analytics)
            case .form(let categoryID):
                PostingFormScreen(categoryID: categoryID,
                                  repo: repo,
                                  drafts: drafts,
                                  analytics: analytics,
                                  step: step)
            case .draft:
                // A restored draft opens with the same category screen — it will
                // offer to continue by itself.
                PostingCategoryScreen(repo: repo, drafts: drafts, analytics: analytics)
            }
        }
    }
}
