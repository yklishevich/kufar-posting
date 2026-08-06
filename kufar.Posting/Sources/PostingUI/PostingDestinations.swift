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
                // Восстановленный черновик открывается тем же экраном
                // категории — он сам предложит продолжить.
                PostingCategoryScreen(repo: repo, drafts: drafts, analytics: analytics)
            }
        }
    }
}
