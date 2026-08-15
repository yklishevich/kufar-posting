import Foundation
import CatalogContracts
import SharedKernel

extension RemotePostingRepository {

    /// The same tree search serves. In a real project this would be one catalogue
    /// endpoint for both surfaces; here the fixtures are duplicated deliberately:
    /// the posting and search packages must not depend on each other.
    static let tree: [CatalogCategory] = [
        CatalogCategory(id: "goods", title: "Goods", vertical: .goods, children: [
            CatalogCategory(id: "goods.electronics", title: "Electronics", vertical: .goods),
            CatalogCategory(id: "goods.furniture", title: "Furniture & interior", vertical: .goods)
        ]),
        CatalogCategory(id: "auto", title: "Vehicles", vertical: .auto, children: [
            CatalogCategory(id: "auto.cars", title: "Cars", vertical: .auto),
            CatalogCategory(id: "auto.parts", title: "Parts", vertical: .auto)
        ])
    ]

    /// The form schema. The fields are the same as in the filter for that
    /// category — and that is no coincidence: one schema on the backend describes
    /// "what we search by", "what we show" and "what we ask when posting" alike.
    static func schema(for categoryID: CatalogCategory.ID) -> Data {
        switch categoryID {
        case "auto", "auto.cars":
            Data("""
            [
              { "id": "brand",   "title": "Make",        "type": "reference",
                "options": ["Volkswagen", "Skoda", "Renault", "Mazda"] },
              { "id": "year",    "title": "Model year",  "type": "number" },
              { "id": "mileage", "title": "Mileage",     "type": "number", "unit": "km" },
              { "id": "vin",     "title": "VIN",         "type": "text" },
              { "id": "customs", "title": "Cleared",     "type": "toggle" },
              { "id": "eco",     "title": "Eco class",   "type": "gauge" }
            ]
            """.utf8)
        default:
            Data("""
            [
              { "id": "state",    "title": "Condition", "type": "reference",
                "options": ["New", "Used"] },
              { "id": "delivery", "title": "Delivery",  "type": "toggle" },
              { "id": "brand",    "title": "Brand",     "type": "text" }
            ]
            """.utf8)
        }
    }
}
