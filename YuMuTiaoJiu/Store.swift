import Foundation
import SwiftUI

final class Store: ObservableObject {
    @Published var favorites: Set<String> = [] { didSet { persist() } }
    @Published var pantry: Set<String> = [] { didSet { persist() } }
    @Published var shopping: [String] = [] { didSet { persist() } }

    private let key = "yumuTiaoJiuStoreV1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SavedState.self, from: data) {
            favorites = Set(decoded.favorites)
            pantry = Set(decoded.pantry)
            shopping = decoded.shopping
        }
    }

    private struct SavedState: Codable {
        var favorites: [String]
        var pantry: [String]
        var shopping: [String]
    }

    private func persist() {
        let state = SavedState(favorites: Array(favorites), pantry: Array(pantry), shopping: shopping)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Matching

    func missingIngredients(for recipe: Recipe) -> [String] {
        recipe.ingredients.map { $0.ingredientID }.filter { !pantry.contains($0) }
    }

    func missingCount(for recipe: Recipe) -> Int {
        missingIngredients(for: recipe).count
    }

    func makeableRecipes() -> [Recipe] {
        Catalog.recipes.filter { missingCount(for: $0) == 0 }
    }

    // MARK: - Actions

    func toggleFavorite(_ recipe: Recipe) {
        if favorites.contains(recipe.id) { favorites.remove(recipe.id) } else { favorites.insert(recipe.id) }
    }

    func togglePantry(_ ingredientID: String) {
        if pantry.contains(ingredientID) { pantry.remove(ingredientID) } else { pantry.insert(ingredientID) }
    }

    func addToShopping(_ ingredientID: String) {
        if !shopping.contains(ingredientID) && !pantry.contains(ingredientID) {
            shopping.append(ingredientID)
        }
    }

    func markBought(_ ingredientID: String) {
        shopping.removeAll { $0 == ingredientID }
        pantry.insert(ingredientID)
    }

    func removeFromShopping(_ ingredientID: String) {
        shopping.removeAll { $0 == ingredientID }
    }
}
