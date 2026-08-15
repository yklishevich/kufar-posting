import SwiftUI
import Observation
import PostingDomain
import PostingInterface
import CatalogContracts
import GoodsInterface
import AutoInterface
import AnalyticsAPI
import Navigation
import SchemaKit
import DesignComponents
import DesignTokens
import SharedKernel

@MainActor
@Observable
final class PostingModel {
    private let repo: any PostingRepository
    private let drafts: any DraftStore
    private let analytics: any AnalyticsTracking

    private(set) var categories: [CatalogCategory] = []
    private(set) var fields: [SchemaField] = []
    private(set) var isPublishing = false
    private(set) var failure: String?

    var draft: PostingDraft {
        didSet { Task { await drafts.save(draft) } }
    }

    init(repo: any PostingRepository, drafts: any DraftStore, analytics: any AnalyticsTracking) {
        self.repo = repo
        self.drafts = drafts
        self.analytics = analytics
        self.draft = PostingDraft()
    }

    var category: CatalogCategory? { categories.find(draft.categoryID) }

    func start() async {
        categories = (try? await repo.categories()) ?? []
        // The draft survives the app being unloaded: posting is the most
        // conversion-sensitive place in the product, and a lost draft is a lost
        // listing.
        if let saved = await drafts.load() {
            draft = saved
            await reloadSchema()
        }
        analytics.track(AnalyticsEvent(name: "posting_started"))
    }

    /// Choosing a category is the user's only decision that determines the
    /// vertical. Everything after that arrives via the schema.
    func select(_ category: CatalogCategory) async {
        draft.categoryID = category.id
        draft.values = [:]
        await reloadSchema()
        analytics.track(AnalyticsEvent(name: "posting_category_selected",
                                       parameters: ["category": category.id]))
    }

    func reloadSchema() async {
        guard let id = draft.categoryID,
              let data = try? await repo.formSchema(categoryID: id)
        else { return }
        fields = (try? JSONDecoder().decode([SchemaField].self, from: data)) ?? []
    }

    func addPhoto() {
        draft.photoCount += 1
    }

    func publish() async -> PublishedListing? {
        guard !isPublishing else { return nil }
        isPublishing = true
        failure = nil
        defer { isPublishing = false }
        do {
            let published = try await repo.publish(draft)
            await drafts.clear()
            analytics.track(AnalyticsEvent(name: "posting_published", parameters: [
                "vertical": published.vertical.rawValue,
                "category": draft.categoryID ?? ""
            ]))
            return published
        } catch PostingError.rejected(let reason) {
            failure = reason
        } catch {
            failure = "Fill in the required fields"
        }
        return nil
    }
}

/// Step one: the category. It is also the only place where the user picks a
/// vertical, though they never see the word "vertical".
package struct PostingCategoryScreen: View {
    @Environment(Router.self) private var router
    @State private var model: PostingModel

    package init(repo: any PostingRepository,
                 drafts: any DraftStore,
                 analytics: any AnalyticsTracking) {
        _model = State(wrappedValue: PostingModel(repo: repo, drafts: drafts, analytics: analytics))
    }

    package var body: some View {
        List {
            if model.draft.categoryID != nil {
                Section {
                    Button("Continue draft") {
                        router.push(PostingRoute.form(model.draft.categoryID ?? ""))
                    }
                }
            }
            Section("Where to post") {
                ForEach(model.categories) { root in
                    DisclosureGroup(root.title) {
                        ForEach(root.children) { child in
                            Button(child.title) {
                                Task {
                                    await model.select(child)
                                    router.push(PostingRoute.form(child.id))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Post a listing")
        .task { await model.start() }
    }
}

/// Step two: the form. The set of fields comes entirely from the backend —
/// "engine displacement" and "condition" are not hardcoded into the client, so a
/// new category ships with no release.
///
/// The `step` slot is the vertical's contribution to another team's flow. Posting
/// knows nothing about verticals: the step's type arrives as a parameter, and
/// which step to supply is the composition root's decision. The schema covers
/// "which questions to ask"; the slot is needed where code is required — the
/// camera, a map, VIN parsing.
struct PostingFormScreen<Step: View>: View {
    @Environment(Router.self) private var router
    @State private var model: PostingModel

    private let categoryID: CatalogCategory.ID
    private let step: (CatalogCategory, Binding<PostingDraft>) -> Step

    init(categoryID: CatalogCategory.ID,
         repo: any PostingRepository,
         drafts: any DraftStore,
         analytics: any AnalyticsTracking,
         @ViewBuilder step: @escaping (CatalogCategory, Binding<PostingDraft>) -> Step) {
        self.categoryID = categoryID
        self.step = step
        _model = State(wrappedValue: PostingModel(repo: repo, drafts: drafts, analytics: analytics))
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: titleBinding)
                TextField("Price, r.", text: priceBinding)
                Button("Add photo (\(model.draft.photoCount))") { model.addPhoto() }
            }

            Section("Parameters") {
                // The same SchemaForm as on the filters screen. One schema
                // describes both "what we search by" and "what we ask when posting".
                SchemaForm(fields: model.fields, values: valuesBinding)
            }

            // The vertical's slot. The category arrives together with the tree,
            // i.e. asynchronously — which is why the closure is called here, in
            // body, rather than when the destination is built: only its id is
            // known there.
            //
            // Changing the category changes the type inside _ConditionalContent,
            // SwiftUI tears down the subtree and resets the step's @State. On the
            // detail screen that would be a bug (5.2); here it is the required
            // behaviour: a scanned VIN must not survive a switch to "Apartments".
            if let category = model.category {
                Section { step(category, draftBinding) }
            }

            if let failure = model.failure {
                Text(failure).foregroundStyle(.red)
            }
        }
        .navigationTitle(model.category?.title ?? "Listing")
        .task {
            await model.start()
            if model.draft.categoryID != categoryID {
                if let category = model.categories.find(categoryID) {
                    await model.select(category)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(model.isPublishing ? "Publishing…" : "Publish",
                          systemImage: "paperplane") {
                Task { await publish() }
            }
            .disabled(model.isPublishing || !model.draft.isPublishable)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(.bar)
        }
    }

    /// The graph's second convergence point after search.
    ///
    /// The published listing's vertical arrives from the backend as data and is
    /// turned into a route here. Not one import of another team's implementation
    /// — contracts only. Add a vertical and the compiler will come here.
    private func publish() async {
        guard let published = await model.publish() else { return }
        switch published.vertical {
        case .goods:
            router.replaceLast(with: GoodsRoute.details(published.id))
        case .auto:
            router.replaceLast(with: AutoRoute.details(published.id))
        }
    }

    private var titleBinding: Binding<String> {
        Binding(get: { model.draft.title }, set: { model.draft.title = $0 })
    }

    private var priceBinding: Binding<String> {
        Binding(
            get: { model.draft.price.map { "\($0)" } ?? "" },
            set: { model.draft.price = Decimal(string: $0) }
        )
    }

    private var valuesBinding: Binding<[String: AttributeValue]> {
        Binding(get: { model.draft.values }, set: { model.draft.values = $0 })
    }

    /// The step writes straight into the draft: `draft`'s `didSet` persists it by
    /// itself, so a recognised VIN survives the app being unloaded just like
    /// everything else the user entered.
    private var draftBinding: Binding<PostingDraft> {
        Binding(get: { model.draft }, set: { model.draft = $0 })
    }
}

extension PostingFormScreen where Step == EmptyView {
    /// The form with no contribution from a vertical: previews, tests, and a
    /// posting demo app built with no verticals at all.
    init(categoryID: CatalogCategory.ID,
         repo: any PostingRepository,
         drafts: any DraftStore,
         analytics: any AnalyticsTracking) {
        self.init(categoryID: categoryID, repo: repo, drafts: drafts,
                  analytics: analytics) { _, _ in EmptyView() }
    }
}
