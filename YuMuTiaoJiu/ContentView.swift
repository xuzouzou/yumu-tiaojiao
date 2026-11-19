import SwiftUI

func fmtAmount(_ v: Double) -> String {
    if v == v.rounded() { return String(Int(v)) }
    return String(format: "%.1f", v)
}

struct ContentView: View {
    var body: some View {
        TabView {
            RecipesTab()
                .tabItem { Label("酒谱", systemImage: "book.pages") }
            PantryTab()
                .tabItem { Label("我的酒柜", systemImage: "cabinet") }
            RandomTab()
                .tabItem { Label("今晚喝啥", systemImage: "dice") }
            FavoritesTab()
                .tabItem { Label("收藏", systemImage: "heart") }
            ShoppingTab()
                .tabItem { Label("采购清单", systemImage: "cart") }
        }
        .tint(.orange)
    }
}

// MARK: - 酒谱列表

struct RecipesTab: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var base = "全部"
    @State private var onlyMakeable = false

    var filtered: [Recipe] {
        Catalog.recipes.filter { r in
            if base != "全部" && r.base != base { return false }
            if onlyMakeable && store.missingCount(for: r) > 0 { return false }
            if !query.isEmpty {
                let q = query.lowercased()
                let inName = r.nameZH.contains(query) || r.nameEN.lowercased().contains(q)
                let inTags = r.tags.contains { $0.contains(query) }
                let inIngs = r.ingredients.contains { Catalog.info($0.ingredientID).name.contains(query) }
                if !inName && !inTags && !inIngs { return false }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Catalog.bases, id: \.self) { b in
                            Button {
                                base = b
                            } label: {
                                Text(b)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(base == b ? Color.orange : Color.secondary.opacity(0.15))
                                    .foregroundStyle(base == b ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                List {
                    Toggle("只看现在能调的", isOn: $onlyMakeable)
                    ForEach(filtered) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeRow(recipe: recipe)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("榆木调酒")
            .searchable(text: $query, prompt: "搜酒名、原料或口味，如：金酒 / 酸爽")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

struct RecipeRow: View {
    @EnvironmentObject var store: Store
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(recipe.nameZH).font(.headline)
                    if store.favorites.contains(recipe.id) {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(.red)
                    }
                }
                Text(recipe.nameEN).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TagChip(text: recipe.base)
                    TagChip(text: recipe.method)
                    if recipe.abv > 0 { TagChip(text: "约\(recipe.abv)°") } else { TagChip(text: "无酒精") }
                }
            }
            Spacer()
            let missing = store.missingCount(for: recipe)
            if store.pantry.isEmpty {
                Text("\(recipe.ingredients.count) 样原料").font(.caption).foregroundStyle(.secondary)
            } else if missing == 0 {
                Label("能调", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold()).foregroundStyle(.green)
            } else {
                Text("差 \(missing) 样")
                    .font(.caption.bold()).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - 配方详情

struct RecipeDetailView: View {
    @EnvironmentObject var store: Store
    let recipe: Recipe
    @State private var servings = 1

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.intro).font(.body)
                    HStack(spacing: 6) {
                        TagChip(text: recipe.base)
                        TagChip(text: recipe.glass)
                        TagChip(text: recipe.method)
                        TagChip(text: "难度 " + String(repeating: "●", count: recipe.difficulty) + String(repeating: "○", count: 3 - recipe.difficulty))
                    }
                    HStack(spacing: 6) {
                        ForEach(recipe.tags, id: \.self) { TagChip(text: $0) }
                    }
                    if !recipe.garnish.isEmpty && recipe.garnish != "无" {
                        Text("装饰：\(recipe.garnish)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Stepper("做 \(servings) 份", value: $servings, in: 1...4)
                    .font(.headline)
                ForEach(recipe.ingredients, id: \.ingredientID) { item in
                    let info = Catalog.info(item.ingredientID)
                    let owned = store.pantry.contains(item.ingredientID)
                    HStack {
                        Image(systemName: owned ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(owned ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name)
                            if !item.note.isEmpty {
                                Text(item.note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(amountText(item))
                            .font(.subheadline.bold())
                        if !owned {
                            Button {
                                store.addToShopping(item.ingredientID)
                            } label: {
                                Image(systemName: "cart.badge.plus")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("原料（绿勾 = 酒柜里有）")
            }

            Section("做法") {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.caption.bold())
                            .frame(width: 20, height: 20)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                        Text(step)
                    }
                    .padding(.vertical, 2)
                }
            }

            if store.missingCount(for: recipe) > 0 {
                Section {
                    Button {
                        for id in store.missingIngredients(for: recipe) { store.addToShopping(id) }
                    } label: {
                        Label("把缺的 \(store.missingCount(for: recipe)) 样原料加入采购清单", systemImage: "cart.badge.plus")
                    }
                }
            }
        }
        .navigationTitle(recipe.nameZH)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleFavorite(recipe)
                } label: {
                    Image(systemName: store.favorites.contains(recipe.id) ? "heart.fill" : "heart")
                        .foregroundStyle(store.favorites.contains(recipe.id) ? .red : .primary)
                }
            }
        }
    }

    func amountText(_ item: RecipeIngredient) -> String {
        if item.unit == "ml" {
            return fmtAmount(item.amount * Double(servings)) + " ml"
        }
        return fmtAmount(item.amount) + " " + item.unit
    }
}

// MARK: - 我的酒柜

struct PantryTab: View {
    @EnvironmentObject var store: Store

    var makeable: [Recipe] { store.makeableRecipes() }
    var almost: [Recipe] {
        Catalog.recipes.filter { store.missingCount(for: $0) == 1 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("酒柜里有 \(store.pantry.count) 样原料")
                            .font(.headline)
                        Text(store.pantry.isEmpty
                             ? "在下面勾选你有的酒和材料，这里会自动算出你能调什么"
                             : "现在就能调 \(makeable.count) 款，再补 1 样又能解锁 \(almost.count) 款")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if !makeable.isEmpty {
                    Section("现在就能调（\(makeable.count)）") {
                        ForEach(makeable) { recipe in
                            NavigationLink(value: recipe) { RecipeRow(recipe: recipe) }
                        }
                    }
                }

                if !almost.isEmpty {
                    Section("只差一样（\(almost.count)）") {
                        ForEach(almost) { recipe in
                            let missingID = store.missingIngredients(for: recipe).first ?? ""
                            HStack {
                                NavigationLink(value: recipe) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(recipe.nameZH)
                                        Text("缺：\(Catalog.info(missingID).name)")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Button {
                                    store.addToShopping(missingID)
                                } label: {
                                    Image(systemName: "cart.badge.plus")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                ForEach(Catalog.ingredientGroups, id: \.self) { group in
                    Section(group) {
                        ForEach(Catalog.ingredients.filter { $0.group == group }) { info in
                            Button {
                                store.togglePantry(info.id)
                            } label: {
                                HStack {
                                    Image(systemName: store.pantry.contains(info.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(store.pantry.contains(info.id) ? .green : .secondary)
                                    Text(info.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text(info.nameEN).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("我的酒柜")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

// MARK: - 今晚喝啥

struct RandomTab: View {
    @EnvironmentObject var store: Store
    @State private var picked: Recipe?
    @State private var onlyMakeable = true
    @State private var spins = 0

    var pool: [Recipe] {
        if onlyMakeable {
            let m = store.makeableRecipes()
            if !m.isEmpty { return m }
        }
        return Catalog.recipes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "wineglass")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                Text("纠结今晚喝什么？")
                    .font(.title3.bold())
                Toggle("只从现在能调的里面选", isOn: $onlyMakeable)
                    .padding(.horizontal, 40)
                Button {
                    picked = pool.randomElement()
                    spins += 1
                } label: {
                    Text(picked == nil ? "帮我选一杯" : "换一杯")
                        .font(.headline)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                if let recipe = picked {
                    NavigationLink(value: recipe) {
                        VStack(spacing: 6) {
                            Text(recipe.nameZH).font(.title2.bold())
                            Text(recipe.nameEN).font(.subheadline).foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                TagChip(text: recipe.base)
                                ForEach(recipe.tags.prefix(3), id: \.self) { TagChip(text: $0) }
                            }
                            Text("点这里看配方 →").font(.caption).foregroundStyle(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .navigationTitle("今晚喝啥")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

// MARK: - 收藏

struct FavoritesTab: View {
    @EnvironmentObject var store: Store

    var favs: [Recipe] {
        Catalog.recipes.filter { store.favorites.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.slash").font(.largeTitle).foregroundStyle(.secondary)
                        Text("还没有收藏的酒谱").foregroundStyle(.secondary)
                        Text("在酒谱详情页点右上角爱心就能收藏").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    List(favs) { recipe in
                        NavigationLink(value: recipe) { RecipeRow(recipe: recipe) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("收藏")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

// MARK: - 采购清单

struct ShoppingTab: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            Group {
                if store.shopping.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart").font(.largeTitle).foregroundStyle(.secondary)
                        Text("采购清单是空的").foregroundStyle(.secondary)
                        Text("在酒谱或酒柜页，把缺的原料加进来").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.shopping, id: \.self) { id in
                                let info = Catalog.info(id)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(info.name)
                                        Text(info.group).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("买到了") {
                                        store.markBought(id)
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.removeFromShopping(id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        } footer: {
                            Text("点「买到了」会自动放进你的酒柜，能调的酒谱也会跟着变多。")
                        }
                    }
                }
            }
            .navigationTitle("采购清单")
        }
    }
}
