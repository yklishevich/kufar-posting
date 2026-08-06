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
        // Черновик переживает выгрузку приложения: подача — самое
        // конверсионное место продукта, и потерянный черновик это
        // потерянное объявление.
        if let saved = await drafts.load() {
            draft = saved
            await reloadSchema()
        }
        analytics.track(AnalyticsEvent(name: "posting_started"))
    }

    /// Выбор категории — единственное решение пользователя, которое
    /// определяет вертикаль. Дальше всё приходит схемой.
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
            failure = "Заполните обязательные поля"
        }
        return nil
    }
}

/// Шаг первый: категория. Она же — единственное место, где пользователь
/// выбирает вертикаль, хотя слова «вертикаль» не видит.
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
                    Button("Продолжить черновик") {
                        router.push(PostingRoute.form(model.draft.categoryID ?? ""))
                    }
                }
            }
            Section("Куда подаём") {
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
        .navigationTitle("Подать объявление")
        .task { await model.start() }
    }
}

/// Шаг второй: форма. Состав полей целиком с бэкенда — «объём двигателя»
/// и «состояние» не захардкожены в клиенте, поэтому новая категория
/// выкатывается без релиза.
///
/// Слот `step` — вклад вертикали в чужой флоу. Подача о вертикалях не знает:
/// тип шага приходит параметром, а какой именно шаг подставить, решает
/// composition root. Схема покрывает «какие вопросы задать»; слот нужен там,
/// где требуется код — камера, карта, разбор VIN.
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
            Section("Основное") {
                TextField("Заголовок", text: titleBinding)
                TextField("Цена, р.", text: priceBinding)
                Button("Добавить фото (\(model.draft.photoCount))") { model.addPhoto() }
            }

            Section("Параметры") {
                // Тот же SchemaForm, что на экране фильтров. Одна схема
                // описывает и «по чему ищем», и «что спрашиваем при подаче».
                SchemaForm(fields: model.fields, values: valuesBinding)
            }

            // Слот вертикали. Категория приезжает вместе с деревом, то есть
            // асинхронно, — поэтому замыкание вызывается здесь, в body, а не
            // при построении destination: там известен только её id.
            //
            // Смена категории меняет тип внутри _ConditionalContent, SwiftUI
            // сносит поддерево и сбрасывает @State шага. В карточке это было бы
            // багом (5.2), здесь — требуемое поведение: отсканированный VIN
            // не должен пережить переключение на «Квартиры».
            if let category = model.category {
                Section { step(category, draftBinding) }
            }

            if let failure = model.failure {
                Text(failure).foregroundStyle(.red)
            }
        }
        .navigationTitle(model.category?.title ?? "Объявление")
        .task {
            await model.start()
            if model.draft.categoryID != categoryID {
                if let category = model.categories.find(categoryID) {
                    await model.select(category)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(model.isPublishing ? "Публикуем…" : "Опубликовать",
                          systemImage: "paperplane") {
                Task { await publish() }
            }
            .disabled(model.isPublishing || !model.draft.isPublishable)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(.bar)
        }
    }

    /// Вторая точка схождения графа после поиска.
    ///
    /// Вертикаль опубликованного объявления приходит с бэкенда данными,
    /// в маршрут превращается здесь. Ни одного импорта чужой реализации —
    /// только контракты. Добавится вертикаль — компилятор придёт сюда.
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

    /// Шаг пишет прямо в черновик: `didSet` у `draft` персистит его сам,
    /// поэтому распознанный VIN переживает выгрузку приложения так же,
    /// как и всё остальное, что ввёл пользователь.
    private var draftBinding: Binding<PostingDraft> {
        Binding(get: { model.draft }, set: { model.draft = $0 })
    }
}

extension PostingFormScreen where Step == EmptyView {
    /// Форма без вклада вертикали: превью, тесты и демо-приложение подачи,
    /// собранное без вертикалей вообще.
    init(categoryID: CatalogCategory.ID,
         repo: any PostingRepository,
         drafts: any DraftStore,
         analytics: any AnalyticsTracking) {
        self.init(categoryID: categoryID, repo: repo, drafts: drafts,
                  analytics: analytics) { _, _ in EmptyView() }
    }
}
