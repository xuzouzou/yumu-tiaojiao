import Foundation

struct IngredientInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let nameEN: String
    let group: String
}

struct RecipeIngredient: Hashable {
    let ingredientID: String
    let amount: Double
    let unit: String
    let note: String
}

struct Recipe: Identifiable, Hashable {
    let id: String
    let nameZH: String
    let nameEN: String
    let base: String
    let glass: String
    let method: String
    let difficulty: Int
    let abv: Int
    let tags: [String]
    let garnish: String
    let intro: String
    let ingredients: [RecipeIngredient]
    let steps: [String]

    static func == (lhs: Recipe, rhs: Recipe) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
