import Foundation
import CatalogContracts
import SharedKernel

extension RemotePostingRepository {

    /// То же дерево, что отдаёт поиск. В настоящем проекте — один эндпоинт
    /// каталога на обе поверхности, здесь фикстуры дублируются намеренно:
    /// пакеты подачи и поиска не должны зависеть друг от друга.
    static let tree: [CatalogCategory] = [
        CatalogCategory(id: "goods", title: "Товары", vertical: .goods, children: [
            CatalogCategory(id: "goods.electronics", title: "Электроника", vertical: .goods),
            CatalogCategory(id: "goods.furniture", title: "Мебель и интерьер", vertical: .goods)
        ]),
        CatalogCategory(id: "auto", title: "Транспорт", vertical: .auto, children: [
            CatalogCategory(id: "auto.cars", title: "Легковые автомобили", vertical: .auto),
            CatalogCategory(id: "auto.parts", title: "Запчасти", vertical: .auto)
        ])
    ]

    /// Схема формы. Поля те же, что в фильтре той же категории, — и это
    /// не совпадение: одна схема на бэкенде описывает и «по чему ищем»,
    /// и «что показываем», и «что спрашиваем при подаче».
    static func schema(for categoryID: CatalogCategory.ID) -> Data {
        switch categoryID {
        case "auto", "auto.cars":
            Data("""
            [
              { "id": "brand",   "title": "Марка",       "type": "reference",
                "options": ["Volkswagen", "Skoda", "Renault", "Mazda"] },
              { "id": "year",    "title": "Год выпуска", "type": "number" },
              { "id": "mileage", "title": "Пробег",      "type": "number", "unit": "км" },
              { "id": "vin",     "title": "VIN",         "type": "text" },
              { "id": "customs", "title": "Растаможен",  "type": "toggle" },
              { "id": "eco",     "title": "Эко-класс",   "type": "gauge" }
            ]
            """.utf8)
        default:
            Data("""
            [
              { "id": "state",    "title": "Состояние", "type": "reference",
                "options": ["Новое", "Б/у"] },
              { "id": "delivery", "title": "Доставка",  "type": "toggle" },
              { "id": "brand",    "title": "Бренд",     "type": "text" }
            ]
            """.utf8)
        }
    }
}
