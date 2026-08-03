//
//  Models.swift
//  Corpo & Alma
//
//  Modelos de dados e estado em memória (dados de exemplo).
//  Quando houver backend / HealthKit, troque o AppModel pela fonte real.
//

import SwiftUI

// MARK: - Métricas de saúde

struct CorpoHealthMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let tint: Color
    let progress: Double   // 0...1 para anéis
}

// MARK: - Refeição / Dieta

enum MealType: String, CaseIterable, Identifiable, Codable {
    case cafe = "Café da manhã"
    case almoco = "Almoço"
    case lanche = "Lanche"
    case jantar = "Jantar"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cafe:   return "sunrise.fill"
        case .almoco: return "sun.max.fill"
        case .lanche: return "cup.and.saucer.fill"
        case .jantar: return "moon.stars.fill"
        }
    }
}

// [2026-07-29] Codable para persistir as refeições do dia (antes o array `meals`
// vivia só em memória e tudo que o usuário adicionava sumia ao fechar o app).
struct Meal: Identifiable, Codable {
    var id = UUID()
    let type: MealType
    let name: String
    let kcal: Int
    let protein: Int   // g
    let carbs: Int     // g
    let fat: Int       // g
    var done: Bool
}

// MARK: - Treino / Exercício

struct Workout: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let focus: String
    let durationMin: Int
    let kcal: Int
    let systemImage: String
    let tint: Color
    let exercises: [Exercise]
}

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable {
    case corporal = "Peso corporal"
    case halteres = "Halteres"
    case barra = "Barra"
    case maquina = "Máquina"
    case cabo = "Cabo/Polia"
    case smith = "Smith"
    case kettlebell = "Kettlebell"
    case elastico = "Elástico"
    case banco = "Banco"
    case anilha = "Anilha"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .corporal:   return "figure.stand"
        case .halteres:   return "dumbbell.fill"
        case .barra:      return "dumbbell.fill"
        case .maquina:    return "gearshape.2.fill"
        case .cabo:       return "figure.strengthtraining.functional"
        case .smith:      return "square.split.2x1.fill"
        case .kettlebell: return "dumbbell.fill"
        case .elastico:   return "figure.flexibility"
        case .banco:      return "chair.lounge.fill"
        case .anilha:     return "circle.circle.fill"
        }
    }
}

struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let sets: Int
    let reps: String
    let equipment: Equipment
    let muscle: String
    let symbol: String            // SF Symbol que ilustra o movimento
    let instructions: [String]
}

/// Treino montado pelo usuário (persistido).
struct CustomWorkout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var exercises: [Exercise]
}

// MARK: - Insight

struct Insight: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    static func == (lhs: Insight, rhs: Insight) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Ponto de gráfico

struct DayPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - Objetivo

enum Goal: String, CaseIterable, Identifiable {
    case perder = "Perder peso"
    case manter = "Manter a forma"
    case ganhar = "Ganhar massa"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .perder: return "arrow.down.right.circle.fill"
        case .manter: return "equal.circle.fill"
        case .ganhar: return "arrow.up.right.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .perder: return Theme.coral
        case .manter: return Theme.azure
        case .ganhar: return Theme.primary
        }
    }
}

// MARK: - Estado do app

final class AppModel: ObservableObject {
    /// Injetável para que os testes usem um domínio próprio e não contaminem
    /// os dados reais de quem estiver usando o app.
    private let store: UserDefaults

    // Onboarding
    @Published var hasOnboarded: Bool { didSet { store.set(hasOnboarded, forKey: "hasOnboarded") } }

    // Perfil
    /// Espelha o perfil único do app: o que a pessoa digitar aqui aparece na
    /// saudação da Alma, e vice-versa. Vazio quando ninguém informou nada.
    @Published var userName: String {
        didSet {
            store.set(userName, forKey: "userName")
            UserProfileStore.salvarNome(userName)
        }
    }
    @Published var goal: Goal { didSet { store.set(goal.rawValue, forKey: "goal") } }

    // [F4] Perfil para o cálculo da meta calórica (100% local, nunca sai do device)
    @Published var sex: BiologicalSex { didSet { store.set(sex.rawValue, forKey: "sexBiological") } }
    @Published var activityLevel: ActivityLevel { didSet { store.set(activityLevel.rawValue, forKey: "activityLevel") } }
    /// Meta definida manualmente pelo usuário. `nil` = usa a sugerida.
    @Published var customKcalGoal: Int? { didSet {
        if let v = customKcalGoal { store.set(v, forKey: "customKcalGoal") }
        else { store.removeObject(forKey: "customKcalGoal") }
    } }

    // Avaliação corporal (persistida)
    @Published var weightKg: Double {
        didSet {
            store.set(weightKg, forKey: "weightKg")
            // [2026-08-03 — BUG B3] `weightLog` não tinha nenhum produtor: não
            // existia um único `WeightEntry(` no app fora da declaração. O
            // gráfico de evolução e a linha "(-2,5 kg desde o primeiro
            // registro)" que a Alma recebe eram código inalcançável.
            registrarPesagem(oldValue: oldValue)
        }
    }

    /// Guarda uma pesagem por dia — a última do dia vence. Sem isso, quem
    /// corrige um dígito errado cria dois pontos no gráfico.
    private func registrarPesagem(oldValue: Double) {
        guard weightKg > 0, weightKg != oldValue else { return }
        let hoje = Calendar.current.startOfDay(for: Date())
        weightLog.removeAll { Calendar.current.isDate($0.date, inSameDayAs: hoje) }
        weightLog.append(WeightEntry(date: Date(), kg: weightKg))
        weightLog.sort { $0.date < $1.date }
    }
    @Published var heightCm: Double { didSet { store.set(heightCm, forKey: "heightCm") } }
    @Published var ageYears: Int { didSet { store.set(ageYears, forKey: "ageYears") } }
    @Published var bodyFat: Double { didSet { store.set(bodyFat, forKey: "bodyFat") } }
    // [2026-08-03 — BUG B6] Havia aqui `@Published var restingHR: Int = 62`:
    // uma frequência cardíaca de repouso inventada, sem escritor e sem
    // persistência, exibida na tela de Saúde como se fosse medição da pessoa.
    // Sobreviveu à faxina de honestidade de ontem no MESMO arquivo.
    // A FC agora vem só do HealthKit; sem dado, a tela mostra "—".

    // Assinatura — premium + teste grátis de 7 dias (igual ao Alma)
    @Published var isPremium: Bool { didSet {
        store.set(isPremium, forKey: "isPremium")
        AlmaBridge.shared.setPremium(isPremium)
    } }
    @Published var trialStartedAt: Date? { didSet {
        store.set(trialStartedAt?.timeIntervalSince1970 ?? 0, forKey: "trialStartedAt")
    } }
    let trialDays = 7

    // Notificações (lembretes locais)
    @Published var notifyWater: Bool { didSet { store.set(notifyWater, forKey: "notifyWater") } }
    @Published var notifyMeals: Bool { didSet { store.set(notifyMeals, forKey: "notifyMeals") } }
    @Published var notifyWorkout: Bool { didSet { store.set(notifyWorkout, forKey: "notifyWorkout") } }
    /// [2026-08-02] Categoria nova: o app cobrava adesão a suplementos sem
    /// nunca lembrar de tomá-los.
    @Published var notifySupplements: Bool { didSet { store.set(notifySupplements, forKey: "notifySupplements") } }
    /// Hora do lembrete de suplementos — a maioria toma junto do café.
    @Published var supplementHour: Int { didSet { store.set(supplementHour, forKey: "supplementHour") } }

    // Aparência: "system" | "light" | "dark"
    @Published var appearanceMode: String { didSet { store.set(appearanceMode, forKey: "appearanceMode") } }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // Plano gerado pela IA (scan corporal)
    @Published var scanResult: ScanResult? { didSet {
        if let r = scanResult, let d = try? JSONEncoder().encode(r) {
            store.set(d, forKey: "scanResult")
        } else {
            store.removeObject(forKey: "scanResult")
        }
    } }

    // Treinos montados pelo usuário (persistidos)
    @Published var customWorkouts: [CustomWorkout] = [] { didSet {
        if let d = try? JSONEncoder().encode(customWorkouts) { store.set(d, forKey: "customWorkouts") }
    } }

    // [F3] Alimentos cadastrados pelo usuário (com marca e código de barras)
    @Published var userFoods: [StoredFood] = [] { didSet {
        if let d = try? JSONEncoder().encode(userFoods) { store.set(d, forKey: "userFoods") }
    } }

    // [F5] Suplementos do usuário (registro pessoal, local)
    @Published var supplements: [Supplement] = [] { didSet {
        if let d = try? JSONEncoder().encode(supplements) { store.set(d, forKey: "supplements") }
    } }

    // [F6] Data em que o plano do scan foi aplicado à Dieta/Treino (nil = não aplicado)
    @Published var planAppliedAt: Date? { didSet {
        store.set(planAppliedAt?.timeIntervalSince1970 ?? 0, forKey: "planAppliedAt")
    } }

    init(store: UserDefaults = .standard) {
        self.store = store
        hasOnboarded = store.bool(forKey: "hasOnboarded")
        // [2026-08-02] Era `?? "Felipe"` — o nome do dono do app virava o nome
        // de todo mundo que instalasse. Agora a fonte é o UserProfileStore e,
        // quando ninguém informou nada, o campo fica vazio e a interface se
        // adapta em vez de inventar.
        userName     = store.string(forKey: "userName") ?? UserProfileStore.nomeSalvo() ?? ""
        goal         = Goal(rawValue: store.string(forKey: "goal") ?? "") ?? .manter
        sex          = BiologicalSex(rawValue: store.string(forKey: "sexBiological") ?? "") ?? .masculino
        activityLevel = ActivityLevel(rawValue: store.string(forKey: "activityLevel") ?? "") ?? .leve
        customKcalGoal = store.object(forKey: "customKcalGoal") as? Int
        let planTs = store.double(forKey: "planAppliedAt")
        planAppliedAt = planTs > 0 ? Date(timeIntervalSince1970: planTs) : nil
        if let d = store.data(forKey: "userFoods"),
           let list = try? JSONDecoder().decode([StoredFood].self, from: d) {
            userFoods = list
        }
        if let d = store.data(forKey: "supplements"),
           let list = try? JSONDecoder().decode([Supplement].self, from: d) {
            supplements = list
        }
        // [Honestidade 2026-08-02] Os defaults fictícios saíram. Antes, quem
        // nunca preencheu as medidas recebia peso 78,4 kg / altura 178 / idade 30
        // / gordura 18,2% — e o app calculava a meta calórica em cima disso,
        // apresentando como se fosse dele. Agora: 0 = "não informado", e a UI
        // convida a completar em vez de exibir número inventado.
        // (Os dados eram coletados no onboarding do Corpo & Alma, que a fusão
        // removeu — daí a regressão.)
        dietaryRestrictions = store.string(forKey: "dietaryRestrictions") ?? ""
        healthConditions    = store.string(forKey: "healthConditions") ?? ""
        weightKg     = store.object(forKey: "weightKg") as? Double ?? 0
        heightCm     = store.object(forKey: "heightCm") as? Double ?? 0
        ageYears     = store.object(forKey: "ageYears") as? Int ?? 0
        bodyFat      = store.object(forKey: "bodyFat") as? Double ?? 0
        // Reset diário da água: zera se for um novo dia.
        //
        // [2026-08-03 — BUG B4 da revisão independente]
        // Aqui havia `waterMl = 0` e só. Atribuição dentro do init NÃO dispara
        // o didSet, então o zero nunca ia para o disco — mas `lastWaterDate`
        // JÁ era carimbado como hoje. Qualquer AppModel construído em seguida
        // no mesmo dia via `isDateInToday == true` e ressuscitava os 1,5 L de
        // ontem. E instâncias descartáveis são construídas o tempo todo: duas
        // por render da Home e uma por mensagem de chat.
        //
        // Resultado: a pessoa acordava com a meta de água já "cumprida" e a
        // Alma recebia "Água: 1,5 L hoje (60% da meta)" com zero ml bebidos.
        // Zerar o disco explicitamente é o que faltava.
        let lastWaterDate = store.object(forKey: "lastWaterDate") as? Date ?? .distantPast
        if Calendar.current.isDateInToday(lastWaterDate) {
            waterMl = store.object(forKey: "waterMl") as? Int ?? 0
        } else {
            waterMl = 0
            store.set(0, forKey: "waterMl")      // ← o zero precisa chegar ao disco
            store.set(Date(), forKey: "lastWaterDate")
        }
        isPremium    = store.bool(forKey: "isPremium")
        let ts       = store.double(forKey: "trialStartedAt")
        trialStartedAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        notifyWater    = store.bool(forKey: "notifyWater")
        notifyMeals    = store.bool(forKey: "notifyMeals")
        notifyWorkout  = store.bool(forKey: "notifyWorkout")
        // [2026-08-03] BUG DE PERSISTÊNCIA. As três séries que sustentam os
        // Insights — peso, calorias por dia e dias de treino — tinham didSet
        // que GRAVA, mas ninguém as LIA de volta no init. Toda abertura do app
        // começava com histórico vazio: o gráfico de peso não tinha passado, a
        // média de calorias reiniciava e a Alma nunca sabia dos treinos.
        // Mesmo tipo de falha do bug das refeições que o Assis pegou em julho
        // ("saí e entrei no app e o que havia inserido sumiu").
        if let d = store.data(forKey: "weightLog"),
           let lista = try? JSONDecoder().decode([WeightEntry].self, from: d) {
            weightLog = lista
        }
        if let d = store.data(forKey: "kcalByDay"),
           let mapa = try? JSONDecoder().decode([String: Int].self, from: d) {
            kcalByDay = mapa
        }
        if let dias = store.array(forKey: "workoutDays") as? [String] {
            workoutDays = Set(dias)
        }

        notifySupplements = store.bool(forKey: "notifySupplements")
        let horaSuplemento = store.integer(forKey: "supplementHour")
        supplementHour = horaSuplemento == 0 ? 9 : horaSuplemento
        appearanceMode = store.string(forKey: "appearanceMode") ?? "system"
        if let d = store.data(forKey: "scanResult") {
            scanResult = try? JSONDecoder().decode(ScanResult.self, from: d)
        }
        if let d = store.data(forKey: "customWorkouts"),
           let list = try? JSONDecoder().decode([CustomWorkout].self, from: d) {
            customWorkouts = list
        }
        // [2026-07-29] Restaura o diário alimentar de hoje (ver persistMeals).
        // Atribuição direta no init NÃO dispara o didSet — nada é regravado aqui.
        meals = Self.loadMealsForToday(from: store)
    }

    // [2026-08-03 — BUG B5 da revisão independente]
    //
    // `imc` era `weightKg / pow(heightCm/100, 2)`. Com os defaults honestos que
    // passaram a valer ontem (peso = 0, altura = 0), isso é 0/0 = NaN. E NaN
    // não casa com nenhum `case` de um switch por faixa: caía no `default:` e o
    // app anunciava **"Obesidade"** para quem tinha acabado de instalar.
    //
    // Foi regressão direta do meu próprio fix de honestidade: troquei os
    // valores fictícios pelo zero e não segui o zero até as telas que o
    // consomem. `imcSeguro` é opcional justamente para que o compilador não
    // deixe mais ninguém exibir IMC sem antes decidir o que fazer sem medidas.
    var imcSeguro: Double? {
        guard hasBodyProfile, heightCm > 0 else { return nil }
        let valor = weightKg / pow(heightCm / 100, 2)
        return valor.isFinite ? valor : nil
    }

    /// Mantido para as telas que já chamavam `imc`; agora nunca devolve NaN.
    var imc: Double { imcSeguro ?? 0 }

    var imcClassificacao: String {
        guard let valor = imcSeguro else { return "sem medidas" }
        switch valor {
        case ..<18.5:   return "Abaixo do peso"
        case 18.5..<25: return "Peso saudável"
        case 25..<30:   return "Sobrepeso"
        default:        return "Obesidade"
        }
    }

    // Metas diárias — [F4] calculadas de verdade (Mifflin-St Jeor × atividade ± objetivo).
    // O usuário pode sobrescrever com uma meta personalizada (customKcalGoal).
    /// [Honestidade] O perfil está completo o bastante para calcular a meta?
    /// Sem isso, NADA de meta calórica — a UI convida a completar.
    var hasBodyProfile: Bool {
        weightKg > 0 && heightCm > 0 && ageYears > 0
    }

    /// O que ainda falta, em português, para a UI pedir com precisão.
    var missingProfileFields: [String] {
        var faltando: [String] = []
        if weightKg <= 0 { faltando.append("peso") }
        if heightCm <= 0 { faltando.append("altura") }
        if ageYears <= 0 { faltando.append("idade") }
        return faltando
    }

    /// Meta sugerida — `nil` quando não há medidas suficientes.
    var suggestedKcalGoal: Int? {
        guard hasBodyProfile else { return nil }
        return NutritionEngine.suggestedKcal(weightKg: weightKg, heightCm: heightCm, ageYears: ageYears,
                                             sex: sex, activity: activityLevel, goal: goal)
    }
    /// Meta em uso — `nil` quando não há medidas nem meta manual.
    var kcalGoal: Int? { customKcalGoal ?? suggestedKcalGoal }
    var proteinGoal: Int? {
        guard let kcal = kcalGoal, weightKg > 0 else { return nil }
        return NutritionEngine.macros(kcal: kcal, weightKg: weightKg).protein
    }
    let waterGoalMl = 2500
    @Published var waterMl: Int { didSet { store.set(waterMl, forKey: "waterMl") } }
    // stepsToday, activeCaloriesBurned e sleepHoursToday são atualizados pela CorpoHomeView via HealthManager
    @Published var stepsToday = 0
    @Published var activeCaloriesBurned: Int = 0
    @Published var sleepHoursToday: Double?
    let stepsGoal = 10000
    let caloriesGoal = 600   // kcal ativas

    // Métricas do dia (Início / Saúde) — valores dinâmicos vindos do HealthKit via CorpoHomeView
    var todayMetrics: [CorpoHealthMetric] {
        let sleepLabel: String
        let sleepProgress: Double
        if let h = sleepHoursToday {
            sleepLabel = String(format: "%.1fh", h)
            sleepProgress = min(h / 8.0, 1.0)
        } else {
            sleepLabel = "—"
            sleepProgress = 0
        }
        let calLabel = activeCaloriesBurned > 0 ? "\(activeCaloriesBurned)" : "—"
        return [
            CorpoHealthMetric(title: "Passos", value: stepsToday > 0 ? "\(stepsToday)" : "—", unit: "de \(stepsGoal)", systemImage: "figure.walk", tint: Theme.primary, progress: Double(stepsToday) / Double(stepsGoal)),
            CorpoHealthMetric(title: "Calorias", value: calLabel, unit: "kcal queimadas", systemImage: "flame.fill", tint: Theme.coral, progress: Double(activeCaloriesBurned) / Double(caloriesGoal)),
            CorpoHealthMetric(title: "Água", value: String(format: "%.1f", Double(waterMl) / 1000), unit: "de 2,5 L", systemImage: "drop.fill", tint: Theme.azure, progress: Double(waterMl) / Double(waterGoalMl)),
            CorpoHealthMetric(title: "Sono", value: sleepLabel, unit: "de 8h ideais", systemImage: "bed.double.fill", tint: Theme.violet, progress: sleepProgress)
        ]
    }

    // Refeições do dia — templates vazios, sem pré-marcação.
    // [2026-07-29] BUG CORRIGIDO: este array não era persistido. Tudo que o
    // usuário adicionava na aba Dieta sumia ao fechar e reabrir o app (só o
    // estado em memória existia). Agora grava em UserDefaults a cada mudança,
    // com reset diário — mesmo padrão já usado pela água (lastWaterDate).
    @Published var meals: [Meal] = AppModel.emptyMealTemplates() {
        didSet {
            persistMeals()
            // [2026-08-03 — BUG B3] `kcalByDay` não tinha NENHUM escritor. O
            // comentário na declaração dizia "gravado ao registrar refeições" e
            // era falso: a média de calorias dos Insights nunca saía do zero e
            // a aba ficava presa em "registre por mais N dias".
            registrarCaloriasDoDia()
        }
    }

    /// Fecha o total do dia toda vez que as refeições mudam. Idempotente: se a
    /// pessoa desmarcar uma refeição, o valor do dia diminui junto.
    private func registrarCaloriasDoDia() {
        kcalByDay[CorpoInsightsEngine.chaveDia(Date())] = kcalConsumed
    }

    /// Templates vazios do dia (uma linha por refeição, sem alimentos).
    static func emptyMealTemplates() -> [Meal] {
        [
            Meal(type: .cafe,   name: "Adicione alimentos", kcal: 0, protein: 0, carbs: 0, fat: 0, done: false),
            Meal(type: .almoco, name: "Adicione alimentos", kcal: 0, protein: 0, carbs: 0, fat: 0, done: false),
            Meal(type: .lanche, name: "Adicione alimentos", kcal: 0, protein: 0, carbs: 0, fat: 0, done: false),
            Meal(type: .jantar, name: "Adicione alimentos", kcal: 0, protein: 0, carbs: 0, fat: 0, done: false)
        ]
    }

    static let mealsKey = "mealsToday"
    static let mealsDateKey = "mealsDate"

    private func persistMeals() {
        guard let data = try? JSONEncoder().encode(meals) else { return }
        store.set(data, forKey: Self.mealsKey)
        store.set(Date(), forKey: Self.mealsDateKey)
    }

    /// Refeições gravadas, se forem de HOJE. Em outro dia (ou sem dado), devolve
    /// os templates vazios — o diário alimentar é diário, não acumulativo.
    static func loadMealsForToday(
        from store: UserDefaults,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [Meal] {
        guard let savedDate = store.object(forKey: mealsDateKey) as? Date,
              calendar.isDate(savedDate, inSameDayAs: now),
              let data = store.data(forKey: mealsKey),
              let saved = try? JSONDecoder().decode([Meal].self, from: data),
              !saved.isEmpty else {
            return emptyMealTemplates()
        }
        return saved
    }

    var kcalConsumed: Int { meals.filter { $0.done }.reduce(0) { $0 + $1.kcal } }
    var proteinConsumed: Int { meals.filter { $0.done }.reduce(0) { $0 + $1.protein } }
    var carbsConsumed: Int { meals.filter { $0.done }.reduce(0) { $0 + $1.carbs } }
    var fatConsumed: Int { meals.filter { $0.done }.reduce(0) { $0 + $1.fat } }

    // Metas de macros — [F4] derivadas da meta calórica atual, não mais fixas.
    var carbsGoal: Int? {
        guard let kcal = kcalGoal, weightKg > 0 else { return nil }
        return NutritionEngine.macros(kcal: kcal, weightKg: weightKg).carbs
    }
    var fatGoal: Int? {
        guard let kcal = kcalGoal, weightKg > 0 else { return nil }
        return NutritionEngine.macros(kcal: kcal, weightKg: weightKg).fat
    }

    // Treinos
    let workouts: [Workout] = [
        Workout(name: "Full Body — Força", focus: "Corpo inteiro", durationMin: 45, kcal: 380, systemImage: "dumbbell.fill", tint: Theme.primary, exercises: [
            Exercise(name: "Agachamento livre", sets: 4, reps: "12 reps", equipment: .barra, muscle: "Pernas e glúteos", symbol: "figure.strengthtraining.functional", instructions: [
                "Posicione a barra sobre os trapézios, pés na largura dos ombros.",
                "Desça flexionando quadril e joelhos até as coxas ficarem paralelas ao chão.",
                "Mantenha o tronco firme e o core contraído.",
                "Suba empurrando o chão com os calcanhares."
            ]),
            Exercise(name: "Supino com halteres", sets: 4, reps: "10 reps", equipment: .halteres, muscle: "Peito e tríceps", symbol: "figure.strengthtraining.traditional", instructions: [
                "Deite no banco com um halter em cada mão, na linha do peito.",
                "Empurre os halteres para cima até estender os cotovelos.",
                "Desça de forma controlada até sentir o alongamento do peito.",
                "Evite estufar a lombar — pés firmes no chão."
            ]),
            Exercise(name: "Remada curvada", sets: 3, reps: "12 reps", equipment: .barra, muscle: "Costas e bíceps", symbol: "figure.rower", instructions: [
                "Incline o tronco à frente com a coluna neutra, joelhos semiflexionados.",
                "Puxe a barra em direção ao umbigo, aproximando as escápulas.",
                "Desça controlando o movimento.",
                "Não use impulso de tronco."
            ]),
            Exercise(name: "Prancha", sets: 3, reps: "45 s", equipment: .corporal, muscle: "Core", symbol: "figure.core.training", instructions: [
                "Apoie antebraços e pontas dos pés no chão.",
                "Mantenha corpo em linha reta, do calcanhar à cabeça.",
                "Contraia o abdômen e os glúteos.",
                "Respire de forma constante."
            ])
        ]),
        Workout(name: "HIIT Queima", focus: "Cardio intenso", durationMin: 20, kcal: 260, systemImage: "bolt.heart.fill", tint: Theme.coral, exercises: [
            Exercise(name: "Burpees", sets: 4, reps: "30 s", equipment: .corporal, muscle: "Corpo inteiro", symbol: "figure.highintensity.intervaltraining", instructions: [
                "Agache e apoie as mãos no chão.",
                "Jogue os pés para trás em posição de prancha.",
                "Volte os pés e salte com os braços para cima.",
                "Repita no maior ritmo seguro."
            ]),
            Exercise(name: "Mountain climbers", sets: 4, reps: "30 s", equipment: .corporal, muscle: "Core e cardio", symbol: "figure.run", instructions: [
                "Comece em posição de prancha alta.",
                "Leve um joelho ao peito e alterne rapidamente.",
                "Mantenha o quadril estável.",
                "Acelere sem perder a forma."
            ]),
            Exercise(name: "Polichinelos", sets: 4, reps: "40 s", equipment: .corporal, muscle: "Cardio", symbol: "figure.mixed.cardio", instructions: [
                "Comece em pé, pés juntos e braços ao lado.",
                "Salte abrindo pernas e levantando os braços.",
                "Salte de volta à posição inicial.",
                "Mantenha ritmo contínuo."
            ]),
            Exercise(name: "Agachamento com salto", sets: 4, reps: "20 reps", equipment: .corporal, muscle: "Pernas", symbol: "figure.cross.training", instructions: [
                "Agache até as coxas ficarem paralelas.",
                "Exploda para cima num salto.",
                "Aterrisse suave, amortecendo com os joelhos.",
                "Desça de novo direto ao próximo salto."
            ])
        ]),
        Workout(name: "Mobilidade & Alongamento", focus: "Recuperação", durationMin: 15, kcal: 80, systemImage: "figure.cooldown", tint: Theme.azure, exercises: [
            Exercise(name: "Alongamento posterior", sets: 2, reps: "30 s", equipment: .corporal, muscle: "Isquiotibiais", symbol: "figure.flexibility", instructions: [
                "Sentado, estenda as pernas à frente.",
                "Incline o tronco buscando os pés.",
                "Vá até sentir alongamento, sem dor.",
                "Respire fundo e relaxe."
            ]),
            Exercise(name: "Gato-camelo", sets: 2, reps: "10 reps", equipment: .corporal, muscle: "Coluna", symbol: "figure.cooldown", instructions: [
                "Apoie mãos e joelhos no chão.",
                "Arredonde a coluna para cima (gato).",
                "Depois afunde a lombar (camelo).",
                "Alterne lentamente com a respiração."
            ]),
            Exercise(name: "Rotação de quadril", sets: 2, reps: "10 cada", equipment: .corporal, muscle: "Quadril", symbol: "figure.flexibility", instructions: [
                "Em pé, mãos na cintura.",
                "Faça círculos amplos com o quadril.",
                "Inverta o sentido na metade.",
                "Mantenha o core ativo."
            ])
        ]),
        Workout(name: "Caminhada consciente", focus: "Leve + respiração", durationMin: 30, kcal: 150, systemImage: "figure.walk.motion", tint: Theme.violet, exercises: [
            Exercise(name: "Caminhada leve", sets: 1, reps: "25 min", equipment: .corporal, muscle: "Cardio", symbol: "figure.walk", instructions: [
                "Mantenha postura ereta e passos confortáveis.",
                "Respire pelo nariz, ritmo constante.",
                "Observe o ambiente e o corpo (atenção plena).",
                "Hidrate-se ao terminar."
            ]),
            Exercise(name: "Respiração 4-7-8", sets: 3, reps: "5 ciclos", equipment: .corporal, muscle: "Respiração", symbol: "lungs.fill", instructions: [
                "Inspire pelo nariz contando até 4.",
                "Segure o ar contando até 7.",
                "Expire pela boca contando até 8.",
                "Repita os ciclos com calma."
            ])
        ])
    ]

    var todayExercises: [Exercise] { workouts.first?.exercises ?? [] }

    // ─────────────────────────────────────────────────────────────────────────
    // [Honestidade 2026-08-02] O QUE HAVIA AQUI ERA FALSO.
    //
    // `insights` eram QUATRO FRASES LITERAIS, iguais para todo usuário, para
    // sempre — o app afirmava "sua média de sono subiu 6% nos últimos 7 dias"
    // sem nunca ter lido sono. `weightTrend` e `caloriesWeek` eram séries
    // inventadas (79,2→78,4 kg; 2100, 1980, 2250 kcal…) desenhando gráficos de
    // uma semana que não existiu.
    //
    // Tudo isso foi REMOVIDO. O que alimenta a aba Insights agora vem de
    // CorpoInsightsEngine, calculado dos registros reais — e quando não há dado
    // suficiente, o app diz isso em vez de inventar.
    // ─────────────────────────────────────────────────────────────────────────

    /// Histórico de peso registrado pelo usuário (data -> kg). Vazio até haver
    /// primeiro registro; nunca semeado com valores de exemplo.
    @Published var weightLog: [WeightEntry] = [] {
        didSet {
            if let d = try? JSONEncoder().encode(weightLog) { store.set(d, forKey: "weightLog") }
        }
    }

    /// Calorias consumidas por dia (yyyy-MM-dd -> kcal), gravado ao registrar
    /// refeições. Base real do gráfico semanal.
    @Published var kcalByDay: [String: Int] = [:] {
        didSet {
            if let d = try? JSONEncoder().encode(kcalByDay) { store.set(d, forKey: "kcalByDay") }
        }
    }

    /// Dias em que houve treino concluído (yyyy-MM-dd).
    @Published var workoutDays: Set<String> = [] {
        didSet {
            store.set(Array(workoutDays), forKey: "workoutDays")
        }
    }

    // [2026-08-02] Campos do onboarding único que a IA usa para NÃO sugerir o
    // que faz mal. Ficam no aparelho; viajam só como parte do resumo, sob o
    // consentimento da categoria "Corpo".
    /// Alergias e restrições alimentares, texto livre.
    @Published var dietaryRestrictions: String {
        didSet { store.set(dietaryRestrictions, forKey: "dietaryRestrictions") }
    }
    /// Condições ou limitações físicas relevantes para o treino.
    @Published var healthConditions: String {
        didSet { store.set(healthConditions, forKey: "healthConditions") }
    }

    // Ações
    func addWater(_ ml: Int) {
        waterMl = min(waterMl + ml, waterGoalMl + 1000)
        store.set(Date(), forKey: "lastWaterDate")
    }

    func toggleMeal(_ meal: Meal) {
        guard let idx = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[idx].done.toggle()
    }

    func removeMeal(_ meal: Meal) {
        meals.removeAll { $0.id == meal.id }
    }

    func addFood(_ food: FoodItem, grams: Int, to type: MealType) {
        let f = Double(grams) / 100.0
        let meal = Meal(
            type: type,
            name: "\(food.name) · \(grams) g",
            kcal: Int((Double(food.kcalPer100) * f).rounded()),
            protein: Int((Double(food.proteinPer100) * f).rounded()),
            carbs: Int((Double(food.carbsPer100) * f).rounded()),
            fat: Int((Double(food.fatPer100) * f).rounded()),
            done: true
        )
        meals.append(meal)
    }

    /// [F3] Resolve um código de barras: cadastro do usuário → cache Open Food Facts → catálogo embutido.
    func food(forBarcode code: String) -> FoodItem? {
        if let mine = userFoods.first(where: { $0.barcode == code }) { return mine.asFoodItem }
        if let cached = OpenFoodFactsService.cached(code) { return cached.asFoodItem }
        return foodDatabase.first { $0.barcode == code }
    }

    // MARK: - [F5] Suplementos

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var todayKey: String { Self.dayFormatter.string(from: Date()) }

    func supplementTakenToday(_ s: Supplement) -> Bool {
        s.takenDates.contains(todayKey)
    }

    /// Marca/desmarca o suplemento como tomado hoje. Se ele tiver calorias
    /// relevantes, entra (ou sai) da Dieta como item do dia — integrado à meta.
    /// Prefixo que marca um item da Dieta como suplemento, e não como refeição.
    /// [2026-08-03] Existe para o contexto da IA poder distinguir os dois: as
    /// calorias da creatina somam na meta (correto), mas tomar creatina não é
    /// "fazer uma refeição" — e a Alma recebia "30 kcal em 1 refeição" de quem
    /// só tinha tomado um suplemento.
    static let prefixoSuplemento = "Suplemento · "

    func toggleSupplementToday(_ s: Supplement) {
        guard let idx = supplements.firstIndex(where: { $0.id == s.id }) else { return }
        let mealName = "\(Self.prefixoSuplemento)\(s.name)\(s.brand.map { " (\($0))" } ?? "")"
        if supplementTakenToday(s) {
            supplements[idx].takenDates.removeAll { $0 == todayKey }
            if s.kcalPerDose > 0 {
                if let mi = meals.firstIndex(where: { $0.name == mealName }) { meals.remove(at: mi) }
            }
        } else {
            supplements[idx].takenDates.append(todayKey)
            if s.kcalPerDose > 0 {
                meals.append(Meal(type: .lanche, name: mealName,
                                  kcal: s.kcalPerDose, protein: s.proteinPerDose,
                                  carbs: 0, fat: 0, done: true))
            }
        }
    }

    /// Aderência: em quantos dos últimos 7 dias o suplemento foi tomado.
    func supplementAdherence7d(_ s: Supplement) -> Int {
        let last7 = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date())
        }.map { Self.dayFormatter.string(from: $0) }
        return s.takenDates.filter { last7.contains($0) }.count
    }

    func removeSupplement(_ s: Supplement) {
        supplements.removeAll { $0.id == s.id }
    }

    // MARK: - [F6] Aplicar o plano do scan na Dieta e no Treino

    /// Substitui o diário de hoje pelas refeições do plano, cria os treinos da
    /// semana como treinos do usuário e alinha a meta calórica à do plano.
    func applyPlan(_ result: ScanResult) {
        scanResult = result
        let plan = result.plan

        // Dieta: refeições do plano viram o diário do dia (não marcadas como feitas).
        let macros = mealMacros(plan: plan)
        meals = plan.meals.map { pm in
            let share = plan.dailyKcal > 0 ? Double(pm.kcal) / Double(plan.dailyKcal) : 0
            return Meal(
                type: MealType(rawValue: pm.type) ?? .lanche,
                name: pm.title + (pm.items.isEmpty ? "" : " — " + pm.items.joined(separator: ", ")),
                kcal: pm.kcal,
                protein: Int((Double(macros.protein) * share).rounded()),
                carbs: Int((Double(macros.carbs) * share).rounded()),
                fat: Int((Double(macros.fat) * share).rounded()),
                done: false
            )
        }

        // Treino: cada dia do plano vira um treino do usuário (removível).
        let planWorkouts: [CustomWorkout] = plan.week.map { day in
            CustomWorkout(
                name: "Plano · \(day.day) — \(day.focus)",
                exercises: day.exercises.map { resolveExercise(named: $0) }
            )
        }
        customWorkouts.removeAll { $0.name.hasPrefix("Plano · ") }
        customWorkouts.append(contentsOf: planWorkouts)

        // Meta: o plano alimenta a mesma fonte de verdade da F4.
        customKcalGoal = max(plan.dailyKcal, NutritionEngine.minKcal)
        planAppliedAt = Date()
    }

    /// Desfaz a aplicação do plano (mantém o resultado do scan salvo na Saúde).
    func undoAppliedPlan() {
        meals = Self.emptyMealTemplates()
        customWorkouts.removeAll { $0.name.hasPrefix("Plano · ") }
        customKcalGoal = nil
        planAppliedAt = nil
    }

    private func mealMacros(plan: GeneratedPlan) -> (protein: Int, carbs: Int, fat: Int) {
        (plan.proteinG, plan.carbsG, plan.fatG)
    }

    /// Acha o exercício no catálogo pelo nome; se não achar, cria um genérico.
    private func resolveExercise(named name: String) -> Exercise {
        let target = name.lowercased()
        if let hit = exerciseLibrary.first(where: { $0.name.lowercased() == target }) { return hit }
        if let close = exerciseLibrary.first(where: { $0.name.lowercased().contains(target) || target.contains($0.name.lowercased()) }) { return close }
        return Exercise(name: name, sets: 3, reps: "10-12", equipment: .corporal,
                        muscle: "Geral", symbol: "figure.strengthtraining.traditional",
                        instructions: ["Execute com forma controlada.", "Ajuste a carga ao seu nível."])
    }

    func addCustomWorkout(name: String, exercises: [Exercise]) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        customWorkouts.append(CustomWorkout(name: clean.isEmpty ? "Meu treino" : clean, exercises: exercises))
    }

    func removeCustomWorkout(_ workout: CustomWorkout) {
        customWorkouts.removeAll { $0.id == workout.id }
    }

    // MARK: Assinatura — helpers
    var trialDaysRemaining: Int {
        guard let start = trialStartedAt else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(trialDays - elapsed, 0)
    }
    /// [2026-08-03] Sempre `false`. O modelo é freemium SEM período de teste
    /// (decisão de julho). A máquina de trial ficou dormente no código —
    /// `startFreeTrial()` nunca é chamado — mas `isTrialActive` ainda entrava
    /// em `hasPremiumAccess`: bastava alguém gravar `trialStartedAt` por
    /// engano para liberar o app inteiro de graça. Fechado na origem.
    var isTrialActive: Bool { false }
    /// Premium local (compra/trial neste app) OU assinatura única vinda do Alma
    /// via App Group (AlmaBridge) — pagou em um, desbloqueia os dois. [2026-07-14]
    var hasPremiumAccess: Bool { isPremium || isTrialActive || AlmaBridge.shared.almaHasPremium }

    func startFreeTrial() { if trialStartedAt == nil { trialStartedAt = Date() } }
    func activatePremium() { isPremium = true }

    /// Exclui permanentemente os dados locais do usuário (exigência App Store / Google Play).
    /// Não cancela a assinatura — isso é feito em Ajustes > Apple ID > Assinaturas.
    ///
    /// [2026-08-03] Esta função tinha ZERO chamadores desde a fusão: o fluxo de
    /// exclusão do Alma (`LocalDataCleanupService`) não a conhecia. A limpeza
    /// das chaves do Corpo agora vive lá, num lugar só, porque o serviço roda
    /// mesmo quando nenhuma tela do Corpo foi aberta (e portanto nenhum
    /// AppModel existe). Esta permanece para o botão dentro do próprio módulo.
    func deleteAllData() {
        let keys = ["hasOnboarded", "userName", "goal", "weightKg", "heightCm", "ageYears",
                    "bodyFat", "waterMl", "isPremium", "trialStartedAt",
                    "notifyWater", "notifyMeals", "notifyWorkout",
                    "notifySupplements", "supplementHour", "scanResult",
                    // [2026-07-29] diário alimentar persistido — dado de saúde,
                    // tem de sair na exclusão (App Store 5.1.1(v) / LGPD).
                    Self.mealsKey, Self.mealsDateKey, "customWorkouts",
                    // [F4/F3/F5/F6] sexo, atividade, meta manual, alimentos, suplementos e plano
                    "sexBiological", "activityLevel", "customKcalGoal", "userFoods",
                    "supplements", "planAppliedAt"]
        keys.forEach { store.removeObject(forKey: $0) }
        OpenFoodFactsService.clearCache()
        meals = Self.emptyMealTemplates()
        sex = .masculino
        activityLevel = .leve
        customKcalGoal = nil
        userFoods = []
        supplements = []
        planAppliedAt = nil

        userName = ""   // [2026-08-02] resetar não pode reintroduzir o nome fictício
        goal = .manter
        weightKg = 0
        heightCm = 0
        ageYears = 0
        bodyFat = 0
        // [2026-08-03 — B9] Era `waterMl = 1450`: a função que existe para
        // APAGAR os dados do usuário reintroduzia 1,45 L de água fictícia.
        waterMl = 0
        isPremium = false
        trialStartedAt = nil
        notifyWater = false
        notifyMeals = false
        notifyWorkout = false
        notifySupplements = false
        supplementHour = 9
        scanResult = nil
        hasOnboarded = false
    }
}

// MARK: - Alimento e banco de dados nutricional

struct FoodItem: Identifiable {
    let id = UUID()
    let name: String
    let kcalPer100: Int
    let proteinPer100: Int
    let carbsPer100: Int
    let fatPer100: Int
    let emoji: String
    var barcode: String? = nil
    /// Marca/fabricante (vem da Open Food Facts ou do cadastro manual).
    var brand: String? = nil
}

/// [F5] Suplemento do usuário — registro pessoal, 100% local.
/// O app NÃO recomenda suplemento nem dose; apenas registra o que o usuário já usa.
struct Supplement: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var brand: String?
    var dose: String            // ex.: "30 g", "1 cápsula", "5 g"
    var timeLabel: String       // ex.: "Manhã", "Pré-treino", "Antes de dormir"
    var notes: String?
    /// Macros por dose (0 = irrelevante). Whey/creatina/hipercalórico somam na Dieta.
    var kcalPerDose: Int = 0
    var proteinPerDose: Int = 0
    /// Dias (yyyy-MM-dd) em que foi marcado como tomado.
    var takenDates: [String] = []
}

/// Alimento cadastrado pelo usuário (Codable — persiste em UserDefaults).
struct StoredFood: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var brand: String?
    var kcalPer100: Int
    var proteinPer100: Int
    var carbsPer100: Int
    var fatPer100: Int
    var barcode: String?

    var asFoodItem: FoodItem {
        FoodItem(name: name, kcalPer100: kcalPer100, proteinPer100: proteinPer100,
                 carbsPer100: carbsPer100, fatPer100: fatPer100, emoji: "📦",
                 barcode: barcode, brand: brand)
    }
}

/// Mini base nutricional (por 100 g). Em produção: API / banco com milhões de itens + código de barras.
let foodDatabase: [FoodItem] = [
    FoodItem(name: "Peito de frango grelhado", kcalPer100: 165, proteinPer100: 31, carbsPer100: 0, fatPer100: 4, emoji: "🍗"),
    FoodItem(name: "Arroz branco cozido", kcalPer100: 130, proteinPer100: 3, carbsPer100: 28, fatPer100: 0, emoji: "🍚"),
    FoodItem(name: "Feijão preto cozido", kcalPer100: 132, proteinPer100: 9, carbsPer100: 24, fatPer100: 1, emoji: "🫘"),
    FoodItem(name: "Ovo cozido", kcalPer100: 155, proteinPer100: 13, carbsPer100: 1, fatPer100: 11, emoji: "🥚"),
    FoodItem(name: "Aveia em flocos", kcalPer100: 389, proteinPer100: 17, carbsPer100: 66, fatPer100: 7, emoji: "🥣"),
    FoodItem(name: "Banana", kcalPer100: 89, proteinPer100: 1, carbsPer100: 23, fatPer100: 0, emoji: "🍌"),
    FoodItem(name: "Maçã", kcalPer100: 52, proteinPer100: 0, carbsPer100: 14, fatPer100: 0, emoji: "🍎"),
    FoodItem(name: "Salmão grelhado", kcalPer100: 208, proteinPer100: 20, carbsPer100: 0, fatPer100: 13, emoji: "🐟"),
    FoodItem(name: "Batata-doce cozida", kcalPer100: 86, proteinPer100: 2, carbsPer100: 20, fatPer100: 0, emoji: "🍠"),
    FoodItem(name: "Iogurte natural integral", kcalPer100: 61, proteinPer100: 4, carbsPer100: 5, fatPer100: 3, emoji: "🥛"),
    FoodItem(name: "Castanha-do-pará", kcalPer100: 656, proteinPer100: 14, carbsPer100: 12, fatPer100: 66, emoji: "🌰"),
    FoodItem(name: "Pão integral", kcalPer100: 247, proteinPer100: 13, carbsPer100: 41, fatPer100: 3, emoji: "🍞"),
    FoodItem(name: "Brócolis cozido", kcalPer100: 35, proteinPer100: 2, carbsPer100: 7, fatPer100: 0, emoji: "🥦"),
    FoodItem(name: "Whey protein (pó)", kcalPer100: 400, proteinPer100: 80, carbsPer100: 8, fatPer100: 6, emoji: "💪", barcode: "7891000100103"),
    FoodItem(name: "Abacate", kcalPer100: 160, proteinPer100: 2, carbsPer100: 9, fatPer100: 15, emoji: "🥑"),
    FoodItem(name: "Tapioca (goma)", kcalPer100: 358, proteinPer100: 0, carbsPer100: 89, fatPer100: 0, emoji: "🤍"),
    FoodItem(name: "Queijo minas frescal", kcalPer100: 264, proteinPer100: 17, carbsPer100: 3, fatPer100: 20, emoji: "🧀"),
    FoodItem(name: "Carne bovina (patinho)", kcalPer100: 219, proteinPer100: 35, carbsPer100: 0, fatPer100: 8, emoji: "🥩"),
    FoodItem(name: "Atum em lata", kcalPer100: 116, proteinPer100: 26, carbsPer100: 0, fatPer100: 1, emoji: "🐟", barcode: "7891167021014"),
    FoodItem(name: "Lentilha cozida", kcalPer100: 116, proteinPer100: 9, carbsPer100: 20, fatPer100: 0, emoji: "🫘"),
    FoodItem(name: "Pasta de amendoim", kcalPer100: 588, proteinPer100: 25, carbsPer100: 20, fatPer100: 50, emoji: "🥜", barcode: "7898024390015"),
    FoodItem(name: "Leite desnatado", kcalPer100: 35, proteinPer100: 3, carbsPer100: 5, fatPer100: 0, emoji: "🥛", barcode: "7891000051207"),
    FoodItem(name: "Macarrão integral cozido", kcalPer100: 124, proteinPer100: 5, carbsPer100: 25, fatPer100: 1, emoji: "🍝"),
    FoodItem(name: "Laranja", kcalPer100: 47, proteinPer100: 1, carbsPer100: 12, fatPer100: 0, emoji: "🍊"),
    FoodItem(name: "Barra de proteína", kcalPer100: 350, proteinPer100: 30, carbsPer100: 35, fatPer100: 10, emoji: "🍫", barcode: "7898939672014"),

    // Carnes e proteínas adicionais
    FoodItem(name: "Frango (coxa sem pele)", kcalPer100: 177, proteinPer100: 24, carbsPer100: 0, fatPer100: 9, emoji: "🍗"),
    FoodItem(name: "Tilápia grelhada", kcalPer100: 128, proteinPer100: 26, carbsPer100: 0, fatPer100: 3, emoji: "🐟"),
    FoodItem(name: "Carne moída (patinho)", kcalPer100: 219, proteinPer100: 26, carbsPer100: 0, fatPer100: 12, emoji: "🥩"),
    FoodItem(name: "Peito de peru", kcalPer100: 135, proteinPer100: 29, carbsPer100: 0, fatPer100: 2, emoji: "🦃"),
    FoodItem(name: "Omelete (2 ovos)", kcalPer100: 154, proteinPer100: 11, carbsPer100: 1, fatPer100: 12, emoji: "🍳"),
    FoodItem(name: "Queijo cottage", kcalPer100: 98, proteinPer100: 11, carbsPer100: 4, fatPer100: 4, emoji: "🧀"),
    FoodItem(name: "Caseína (pó)", kcalPer100: 380, proteinPer100: 78, carbsPer100: 8, fatPer100: 4, emoji: "💪"),

    // Carboidratos
    FoodItem(name: "Arroz integral cozido", kcalPer100: 111, proteinPer100: 3, carbsPer100: 23, fatPer100: 1, emoji: "🍚"),
    FoodItem(name: "Batata inglesa cozida", kcalPer100: 77, proteinPer100: 2, carbsPer100: 17, fatPer100: 0, emoji: "🥔"),
    FoodItem(name: "Mandioca cozida", kcalPer100: 125, proteinPer100: 1, carbsPer100: 30, fatPer100: 0, emoji: "🌿"),
    FoodItem(name: "Pão de forma branco", kcalPer100: 266, proteinPer100: 9, carbsPer100: 50, fatPer100: 4, emoji: "🍞"),
    FoodItem(name: "Macarrão branco cozido", kcalPer100: 158, proteinPer100: 6, carbsPer100: 31, fatPer100: 1, emoji: "🍝"),
    FoodItem(name: "Granola (sem açúcar)", kcalPer100: 440, proteinPer100: 11, carbsPer100: 60, fatPer100: 18, emoji: "🥣"),
    FoodItem(name: "Cuscuz cozido", kcalPer100: 112, proteinPer100: 4, carbsPer100: 23, fatPer100: 0, emoji: "🫓"),

    // Frutas
    FoodItem(name: "Morango", kcalPer100: 32, proteinPer100: 1, carbsPer100: 8, fatPer100: 0, emoji: "🍓"),
    FoodItem(name: "Mamão papaia", kcalPer100: 43, proteinPer100: 1, carbsPer100: 11, fatPer100: 0, emoji: "🍈"),
    FoodItem(name: "Uva", kcalPer100: 69, proteinPer100: 1, carbsPer100: 18, fatPer100: 0, emoji: "🍇"),
    FoodItem(name: "Kiwi", kcalPer100: 61, proteinPer100: 1, carbsPer100: 15, fatPer100: 1, emoji: "🥝"),
    FoodItem(name: "Manga", kcalPer100: 60, proteinPer100: 1, carbsPer100: 15, fatPer100: 0, emoji: "🥭"),
    FoodItem(name: "Abacaxi", kcalPer100: 50, proteinPer100: 1, carbsPer100: 13, fatPer100: 0, emoji: "🍍"),

    // Vegetais e legumes
    FoodItem(name: "Espinafre cozido", kcalPer100: 23, proteinPer100: 3, carbsPer100: 4, fatPer100: 0, emoji: "🥬"),
    FoodItem(name: "Cenoura cozida", kcalPer100: 41, proteinPer100: 1, carbsPer100: 10, fatPer100: 0, emoji: "🥕"),
    FoodItem(name: "Tomate", kcalPer100: 18, proteinPer100: 1, carbsPer100: 4, fatPer100: 0, emoji: "🍅"),
    FoodItem(name: "Pepino", kcalPer100: 15, proteinPer100: 1, carbsPer100: 4, fatPer100: 0, emoji: "🥒"),
    FoodItem(name: "Alface", kcalPer100: 14, proteinPer100: 1, carbsPer100: 3, fatPer100: 0, emoji: "🥗"),

    // Gorduras e oleaginosas
    FoodItem(name: "Azeite de oliva", kcalPer100: 884, proteinPer100: 0, carbsPer100: 0, fatPer100: 100, emoji: "🫒"),
    FoodItem(name: "Amendoim", kcalPer100: 567, proteinPer100: 26, carbsPer100: 16, fatPer100: 49, emoji: "🥜"),
    FoodItem(name: "Amêndoa", kcalPer100: 579, proteinPer100: 21, carbsPer100: 22, fatPer100: 50, emoji: "🌰"),
    FoodItem(name: "Coco ralado (sem açúcar)", kcalPer100: 660, proteinPer100: 7, carbsPer100: 24, fatPer100: 64, emoji: "🥥"),

    // Laticínios
    FoodItem(name: "Leite integral", kcalPer100: 61, proteinPer100: 3, carbsPer100: 5, fatPer100: 3, emoji: "🥛", barcode: "7891000100196"),
    FoodItem(name: "Iogurte grego integral", kcalPer100: 97, proteinPer100: 9, carbsPer100: 4, fatPer100: 5, emoji: "🥛"),
    FoodItem(name: "Requeijão cremoso", kcalPer100: 240, proteinPer100: 8, carbsPer100: 5, fatPer100: 21, emoji: "🧈"),

    // Bebidas e suplementos
    FoodItem(name: "Café preto (sem açúcar)", kcalPer100: 2, proteinPer100: 0, carbsPer100: 0, fatPer100: 0, emoji: "☕"),
    FoodItem(name: "Suco de laranja natural", kcalPer100: 45, proteinPer100: 1, carbsPer100: 11, fatPer100: 0, emoji: "🍊"),
    FoodItem(name: "Vitamina C (comprimido)", kcalPer100: 0, proteinPer100: 0, carbsPer100: 0, fatPer100: 0, emoji: "💊"),
    FoodItem(name: "BCAA (pó)", kcalPer100: 110, proteinPer100: 27, carbsPer100: 0, fatPer100: 0, emoji: "💊"),
    FoodItem(name: "Creatina monoidratada (pó)", kcalPer100: 0, proteinPer100: 0, carbsPer100: 0, fatPer100: 0, emoji: "💊"),

    // MARK: - Ovos (preparações)
    FoodItem(name: "Ovo frito sem óleo", kcalPer100: 170, proteinPer100: 13, carbsPer100: 1, fatPer100: 13, emoji: "🍳"),
    FoodItem(name: "Ovo frito com óleo", kcalPer100: 196, proteinPer100: 13, carbsPer100: 1, fatPer100: 15, emoji: "🍳"),
    FoodItem(name: "Ovo mexido (sem óleo)", kcalPer100: 148, proteinPer100: 10, carbsPer100: 1, fatPer100: 11, emoji: "🍳"),
    FoodItem(name: "Omelete simples", kcalPer100: 154, proteinPer100: 11, carbsPer100: 1, fatPer100: 12, emoji: "🍳"),
    FoodItem(name: "Clara de ovo cozida", kcalPer100: 52, proteinPer100: 11, carbsPer100: 1, fatPer100: 0, emoji: "🥚"),
    FoodItem(name: "Gema de ovo", kcalPer100: 322, proteinPer100: 16, carbsPer100: 1, fatPer100: 27, emoji: "🥚"),
    FoodItem(name: "Ovo de codorna cozido", kcalPer100: 158, proteinPer100: 13, carbsPer100: 1, fatPer100: 11, emoji: "🥚"),

    // MARK: - Pães e massas
    FoodItem(name: "Pão francês", kcalPer100: 300, proteinPer100: 8, carbsPer100: 58, fatPer100: 3, emoji: "🥖"),
    FoodItem(name: "Pão de forma branco", kcalPer100: 266, proteinPer100: 9, carbsPer100: 49, fatPer100: 4, emoji: "🍞"),
    FoodItem(name: "Pão de forma integral", kcalPer100: 247, proteinPer100: 11, carbsPer100: 44, fatPer100: 4, emoji: "🍞"),
    FoodItem(name: "Pão de queijo assado", kcalPer100: 331, proteinPer100: 7, carbsPer100: 50, fatPer100: 12, emoji: "🧀"),
    FoodItem(name: "Bisnaga (pão doce)", kcalPer100: 280, proteinPer100: 9, carbsPer100: 52, fatPer100: 4, emoji: "🍞"),
    FoodItem(name: "Croissant simples", kcalPer100: 406, proteinPer100: 8, carbsPer100: 46, fatPer100: 21, emoji: "🥐"),
    FoodItem(name: "Wrap integral", kcalPer100: 306, proteinPer100: 9, carbsPer100: 54, fatPer100: 6, emoji: "🌯"),
    FoodItem(name: "Macarrão branco cozido", kcalPer100: 131, proteinPer100: 5, carbsPer100: 25, fatPer100: 1, emoji: "🍝"),
    FoodItem(name: "Lasanha com carne", kcalPer100: 158, proteinPer100: 8, carbsPer100: 14, fatPer100: 7, emoji: "🍝"),
    FoodItem(name: "Nhoque de batata cozido", kcalPer100: 128, proteinPer100: 4, carbsPer100: 27, fatPer100: 1, emoji: "🍝"),

    // MARK: - Frango (cortes e preparações)
    FoodItem(name: "Coxa de frango assada", kcalPer100: 191, proteinPer100: 24, carbsPer100: 0, fatPer100: 10, emoji: "🍗"),
    FoodItem(name: "Coxa de frango grelhada", kcalPer100: 179, proteinPer100: 24, carbsPer100: 0, fatPer100: 9, emoji: "🍗"),
    FoodItem(name: "Sobrecoxa de frango assada", kcalPer100: 213, proteinPer100: 20, carbsPer100: 0, fatPer100: 14, emoji: "🍗"),
    FoodItem(name: "Frango inteiro assado", kcalPer100: 239, proteinPer100: 27, carbsPer100: 0, fatPer100: 14, emoji: "🍗"),
    FoodItem(name: "Peito de frango cozido", kcalPer100: 158, proteinPer100: 30, carbsPer100: 0, fatPer100: 3, emoji: "🍗"),
    FoodItem(name: "Frango à passarinho", kcalPer100: 227, proteinPer100: 22, carbsPer100: 4, fatPer100: 13, emoji: "🍗"),
    FoodItem(name: "Nugget de frango (forno)", kcalPer100: 236, proteinPer100: 15, carbsPer100: 18, fatPer100: 11, emoji: "🍗"),
    FoodItem(name: "Frango desfiado cozido", kcalPer100: 165, proteinPer100: 31, carbsPer100: 0, fatPer100: 4, emoji: "🍗"),

    // MARK: - Carnes vermelhas e embutidos
    FoodItem(name: "Alcatra grelhada", kcalPer100: 211, proteinPer100: 33, carbsPer100: 0, fatPer100: 8, emoji: "🥩"),
    FoodItem(name: "Picanha grelhada", kcalPer100: 290, proteinPer100: 28, carbsPer100: 0, fatPer100: 19, emoji: "🥩"),
    FoodItem(name: "Coxão mole grelhado", kcalPer100: 195, proteinPer100: 32, carbsPer100: 0, fatPer100: 7, emoji: "🥩"),
    FoodItem(name: "Carne moída refogada", kcalPer100: 215, proteinPer100: 26, carbsPer100: 0, fatPer100: 12, emoji: "🥩"),
    FoodItem(name: "Filé mignon grelhado", kcalPer100: 230, proteinPer100: 30, carbsPer100: 0, fatPer100: 12, emoji: "🥩"),
    FoodItem(name: "Costela bovina assada", kcalPer100: 294, proteinPer100: 26, carbsPer100: 0, fatPer100: 21, emoji: "🥩"),
    FoodItem(name: "Fraldinha grelhada", kcalPer100: 200, proteinPer100: 30, carbsPer100: 0, fatPer100: 8, emoji: "🥩"),
    FoodItem(name: "Bacon grelhado", kcalPer100: 541, proteinPer100: 37, carbsPer100: 1, fatPer100: 42, emoji: "🥓"),
    FoodItem(name: "Linguiça calabresa grelhada", kcalPer100: 325, proteinPer100: 16, carbsPer100: 1, fatPer100: 29, emoji: "🌭"),
    FoodItem(name: "Linguiça toscana grelhada", kcalPer100: 288, proteinPer100: 15, carbsPer100: 2, fatPer100: 25, emoji: "🌭"),
    FoodItem(name: "Salsicha cozida", kcalPer100: 259, proteinPer100: 13, carbsPer100: 2, fatPer100: 23, emoji: "🌭"),
    FoodItem(name: "Presunto fatiado", kcalPer100: 130, proteinPer100: 18, carbsPer100: 2, fatPer100: 6, emoji: "🥩"),
    FoodItem(name: "Mortadela", kcalPer100: 290, proteinPer100: 14, carbsPer100: 3, fatPer100: 25, emoji: "🥩"),
    FoodItem(name: "Peito de peru fatiado", kcalPer100: 109, proteinPer100: 20, carbsPer100: 1, fatPer100: 3, emoji: "🦃"),
    FoodItem(name: "Hambúrguer bovino grelhado", kcalPer100: 245, proteinPer100: 20, carbsPer100: 0, fatPer100: 18, emoji: "🍔"),

    // MARK: - Peixes e frutos do mar
    FoodItem(name: "Tilápia grelhada", kcalPer100: 128, proteinPer100: 26, carbsPer100: 0, fatPer100: 3, emoji: "🐟"),
    FoodItem(name: "Sardinha em conserva", kcalPer100: 208, proteinPer100: 25, carbsPer100: 0, fatPer100: 11, emoji: "🐟"),
    FoodItem(name: "Bacalhau cozido", kcalPer100: 176, proteinPer100: 40, carbsPer100: 0, fatPer100: 1, emoji: "🐟"),
    FoodItem(name: "Camarão cozido", kcalPer100: 99, proteinPer100: 24, carbsPer100: 0, fatPer100: 1, emoji: "🦐"),
    FoodItem(name: "Frango do mar (merluza) grelhado", kcalPer100: 90, proteinPer100: 18, carbsPer100: 0, fatPer100: 2, emoji: "🐟"),
    FoodItem(name: "Atum fresco grelhado", kcalPer100: 184, proteinPer100: 30, carbsPer100: 0, fatPer100: 6, emoji: "🐟"),

    // MARK: - Laticínios e derivados
    FoodItem(name: "Queijo mussarela", kcalPer100: 315, proteinPer100: 22, carbsPer100: 2, fatPer100: 24, emoji: "🧀"),
    FoodItem(name: "Queijo prato", kcalPer100: 358, proteinPer100: 23, carbsPer100: 2, fatPer100: 28, emoji: "🧀"),
    FoodItem(name: "Queijo parmesão ralado", kcalPer100: 431, proteinPer100: 38, carbsPer100: 4, fatPer100: 29, emoji: "🧀"),
    FoodItem(name: "Queijo cottage", kcalPer100: 98, proteinPer100: 11, carbsPer100: 3, fatPer100: 4, emoji: "🧀"),
    FoodItem(name: "Queijo cheddar", kcalPer100: 402, proteinPer100: 25, carbsPer100: 1, fatPer100: 33, emoji: "🧀"),
    FoodItem(name: "Manteiga", kcalPer100: 726, proteinPer100: 1, carbsPer100: 0, fatPer100: 82, emoji: "🧈"),
    FoodItem(name: "Creme de leite (lata)", kcalPer100: 312, proteinPer100: 2, carbsPer100: 3, fatPer100: 32, emoji: "🥛"),
    FoodItem(name: "Leite semidesnatado", kcalPer100: 49, proteinPer100: 3, carbsPer100: 5, fatPer100: 2, emoji: "🥛"),
    FoodItem(name: "Iogurte desnatado natural", kcalPer100: 47, proteinPer100: 4, carbsPer100: 6, fatPer100: 1, emoji: "🥛"),
    FoodItem(name: "Leite em pó integral", kcalPer100: 496, proteinPer100: 26, carbsPer100: 38, fatPer100: 26, emoji: "🥛"),

    // MARK: - Carboidratos e tubérculos
    FoodItem(name: "Batata inglesa cozida", kcalPer100: 86, proteinPer100: 2, carbsPer100: 20, fatPer100: 0, emoji: "🥔"),
    FoodItem(name: "Batata inglesa frita", kcalPer100: 312, proteinPer100: 4, carbsPer100: 41, fatPer100: 15, emoji: "🍟"),
    FoodItem(name: "Mandioca cozida", kcalPer100: 125, proteinPer100: 1, carbsPer100: 30, fatPer100: 0, emoji: "🍠"),
    FoodItem(name: "Polenta cozida", kcalPer100: 70, proteinPer100: 2, carbsPer100: 15, fatPer100: 0, emoji: "🌽"),
    FoodItem(name: "Cuscuz paulista simples", kcalPer100: 180, proteinPer100: 5, carbsPer100: 37, fatPer100: 2, emoji: "🌾"),
    FoodItem(name: "Arroz integral cozido", kcalPer100: 123, proteinPer100: 3, carbsPer100: 26, fatPer100: 1, emoji: "🍚"),
    FoodItem(name: "Arroz com feijão (prato)", kcalPer100: 134, proteinPer100: 5, carbsPer100: 26, fatPer100: 2, emoji: "🍛"),
    FoodItem(name: "Feijão-carioca cozido", kcalPer100: 128, proteinPer100: 8, carbsPer100: 23, fatPer100: 1, emoji: "🫘"),
    FoodItem(name: "Quinoa cozida", kcalPer100: 120, proteinPer100: 4, carbsPer100: 21, fatPer100: 2, emoji: "🌾"),
    FoodItem(name: "Grão-de-bico cozido", kcalPer100: 164, proteinPer100: 9, carbsPer100: 27, fatPer100: 3, emoji: "🫘"),

    // MARK: - Frutas
    FoodItem(name: "Melancia", kcalPer100: 30, proteinPer100: 1, carbsPer100: 8, fatPer100: 0, emoji: "🍉"),
    FoodItem(name: "Melão", kcalPer100: 34, proteinPer100: 1, carbsPer100: 8, fatPer100: 0, emoji: "🍈"),
    FoodItem(name: "Morango", kcalPer100: 32, proteinPer100: 1, carbsPer100: 8, fatPer100: 0, emoji: "🍓"),
    FoodItem(name: "Uva (sem semente)", kcalPer100: 69, proteinPer100: 1, carbsPer100: 18, fatPer100: 0, emoji: "🍇"),
    FoodItem(name: "Pera", kcalPer100: 57, proteinPer100: 0, carbsPer100: 15, fatPer100: 0, emoji: "🍐"),
    FoodItem(name: "Mamão papaia", kcalPer100: 43, proteinPer100: 0, carbsPer100: 11, fatPer100: 0, emoji: "🍈"),
    FoodItem(name: "Caju", kcalPer100: 43, proteinPer100: 1, carbsPer100: 10, fatPer100: 0, emoji: "🍊"),
    FoodItem(name: "Goiaba", kcalPer100: 54, proteinPer100: 2, carbsPer100: 12, fatPer100: 1, emoji: "🍏"),
    FoodItem(name: "Maracujá (polpa)", kcalPer100: 68, proteinPer100: 2, carbsPer100: 13, fatPer100: 1, emoji: "🍊"),
    FoodItem(name: "Limão (suco)", kcalPer100: 29, proteinPer100: 0, carbsPer100: 9, fatPer100: 0, emoji: "🍋"),
    FoodItem(name: "Ameixa fresca", kcalPer100: 46, proteinPer100: 1, carbsPer100: 11, fatPer100: 0, emoji: "🫐"),
    FoodItem(name: "Mirtilo (blueberry)", kcalPer100: 57, proteinPer100: 1, carbsPer100: 14, fatPer100: 0, emoji: "🫐"),

    // MARK: - Verduras e legumes
    FoodItem(name: "Beterraba cozida", kcalPer100: 43, proteinPer100: 2, carbsPer100: 10, fatPer100: 0, emoji: "🫛"),
    FoodItem(name: "Chuchu cozido", kcalPer100: 22, proteinPer100: 1, carbsPer100: 5, fatPer100: 0, emoji: "🥬"),
    FoodItem(name: "Abobrinha cozida", kcalPer100: 17, proteinPer100: 1, carbsPer100: 3, fatPer100: 0, emoji: "🥒"),
    FoodItem(name: "Quiabo cozido", kcalPer100: 33, proteinPer100: 2, carbsPer100: 7, fatPer100: 0, emoji: "🫛"),
    FoodItem(name: "Couve refogada", kcalPer100: 45, proteinPer100: 3, carbsPer100: 6, fatPer100: 1, emoji: "🥬"),
    FoodItem(name: "Couve-flor cozida", kcalPer100: 25, proteinPer100: 2, carbsPer100: 5, fatPer100: 0, emoji: "🥦"),
    FoodItem(name: "Ervilha cozida", kcalPer100: 84, proteinPer100: 5, carbsPer100: 14, fatPer100: 0, emoji: "🫛"),
    FoodItem(name: "Milho cozido", kcalPer100: 86, proteinPer100: 3, carbsPer100: 19, fatPer100: 1, emoji: "🌽"),
    FoodItem(name: "Berinjela assada", kcalPer100: 25, proteinPer100: 1, carbsPer100: 6, fatPer100: 0, emoji: "🍆"),
    FoodItem(name: "Pimentão vermelho", kcalPer100: 31, proteinPer100: 1, carbsPer100: 7, fatPer100: 0, emoji: "🫑"),
    FoodItem(name: "Cebola crua", kcalPer100: 40, proteinPer100: 1, carbsPer100: 9, fatPer100: 0, emoji: "🧅"),
    FoodItem(name: "Alho", kcalPer100: 149, proteinPer100: 6, carbsPer100: 33, fatPer100: 1, emoji: "🧄"),

    // MARK: - Snacks, lanches e comida brasileira
    FoodItem(name: "Coxinha de frango (forno)", kcalPer100: 252, proteinPer100: 11, carbsPer100: 28, fatPer100: 10, emoji: "🍗"),
    FoodItem(name: "Esfiha de carne assada", kcalPer100: 275, proteinPer100: 10, carbsPer100: 35, fatPer100: 10, emoji: "🫓"),
    FoodItem(name: "Pastel de forno de frango", kcalPer100: 288, proteinPer100: 10, carbsPer100: 34, fatPer100: 12, emoji: "🥐"),
    FoodItem(name: "Biscoito de arroz", kcalPer100: 381, proteinPer100: 8, carbsPer100: 82, fatPer100: 2, emoji: "🍘"),
    FoodItem(name: "Granola sem açúcar", kcalPer100: 419, proteinPer100: 10, carbsPer100: 60, fatPer100: 15, emoji: "🥣"),
    FoodItem(name: "Barra de cereal (média)", kcalPer100: 380, proteinPer100: 6, carbsPer100: 70, fatPer100: 9, emoji: "🍫"),
    FoodItem(name: "Pipoca sem manteiga", kcalPer100: 375, proteinPer100: 11, carbsPer100: 74, fatPer100: 4, emoji: "🍿"),

    // MARK: - Bebidas e sucos
    FoodItem(name: "Água de coco", kcalPer100: 19, proteinPer100: 0, carbsPer100: 4, fatPer100: 0, emoji: "🥥"),
    FoodItem(name: "Suco de uva integral", kcalPer100: 62, proteinPer100: 0, carbsPer100: 15, fatPer100: 0, emoji: "🍇"),
    FoodItem(name: "Suco de maçã natural", kcalPer100: 46, proteinPer100: 0, carbsPer100: 11, fatPer100: 0, emoji: "🍎"),
    FoodItem(name: "Leite com chocolate (integral)", kcalPer100: 83, proteinPer100: 4, carbsPer100: 11, fatPer100: 3, emoji: "🍫"),
    FoodItem(name: "Chá verde (sem açúcar)", kcalPer100: 1, proteinPer100: 0, carbsPer100: 0, fatPer100: 0, emoji: "🍵"),
    FoodItem(name: "Refrigerante cola (350 ml)", kcalPer100: 42, proteinPer100: 0, carbsPer100: 11, fatPer100: 0, emoji: "🥤"),
    FoodItem(name: "Refrigerante zero", kcalPer100: 0, proteinPer100: 0, carbsPer100: 0, fatPer100: 0, emoji: "🥤"),

    // MARK: - Açaí e sobremesas
    FoodItem(name: "Açaí na tigela (sem acompanhamento)", kcalPer100: 247, proteinPer100: 3, carbsPer100: 21, fatPer100: 17, emoji: "🫐"),
    FoodItem(name: "Açaí com granola e banana", kcalPer100: 190, proteinPer100: 3, carbsPer100: 28, fatPer100: 8, emoji: "🫐"),
    FoodItem(name: "Brigadeiro", kcalPer100: 428, proteinPer100: 5, carbsPer100: 65, fatPer100: 17, emoji: "🍫"),
    FoodItem(name: "Pudim de leite condensado", kcalPer100: 232, proteinPer100: 6, carbsPer100: 39, fatPer100: 6, emoji: "🍮"),
    FoodItem(name: "Sorvete de creme", kcalPer100: 207, proteinPer100: 3, carbsPer100: 24, fatPer100: 11, emoji: "🍦"),
    FoodItem(name: "Bolo de cenoura com cobertura", kcalPer100: 332, proteinPer100: 5, carbsPer100: 51, fatPer100: 12, emoji: "🎂"),
    FoodItem(name: "Tapioca com queijo e presunto", kcalPer100: 205, proteinPer100: 9, carbsPer100: 37, fatPer100: 3, emoji: "🤍"),

    // MARK: - Oleaginosas e gorduras saudáveis
    FoodItem(name: "Nozes", kcalPer100: 654, proteinPer100: 15, carbsPer100: 14, fatPer100: 65, emoji: "🌰"),
    FoodItem(name: "Castanha de caju", kcalPer100: 553, proteinPer100: 18, carbsPer100: 30, fatPer100: 44, emoji: "🥜"),
    FoodItem(name: "Chia (semente)", kcalPer100: 486, proteinPer100: 17, carbsPer100: 42, fatPer100: 31, emoji: "🌾"),
    FoodItem(name: "Linhaça dourada", kcalPer100: 534, proteinPer100: 18, carbsPer100: 29, fatPer100: 42, emoji: "🌾"),
    FoodItem(name: "Óleo de coco", kcalPer100: 862, proteinPer100: 0, carbsPer100: 0, fatPer100: 100, emoji: "🥥"),
    FoodItem(name: "Ghee (manteiga clarificada)", kcalPer100: 900, proteinPer100: 0, carbsPer100: 0, fatPer100: 99, emoji: "🧈"),

    // MARK: - Proteínas vegetais
    FoodItem(name: "Tofu firme", kcalPer100: 76, proteinPer100: 8, carbsPer100: 2, fatPer100: 4, emoji: "🫘"),
    FoodItem(name: "Proteína de soja texturizada (hidratada)", kcalPer100: 140, proteinPer100: 17, carbsPer100: 11, fatPer100: 3, emoji: "🫘"),
    FoodItem(name: "Edamame cozido", kcalPer100: 122, proteinPer100: 11, carbsPer100: 10, fatPer100: 5, emoji: "🫛"),

    // MARK: - Molhos e temperos
    FoodItem(name: "Azeite de oliva extra virgem", kcalPer100: 884, proteinPer100: 0, carbsPer100: 0, fatPer100: 100, emoji: "🫒"),
    FoodItem(name: "Mel", kcalPer100: 304, proteinPer100: 0, carbsPer100: 82, fatPer100: 0, emoji: "🍯"),
    FoodItem(name: "Geleia de morango", kcalPer100: 250, proteinPer100: 0, carbsPer100: 62, fatPer100: 0, emoji: "🍓"),
    FoodItem(name: "Maionese tradicional", kcalPer100: 680, proteinPer100: 1, carbsPer100: 3, fatPer100: 75, emoji: "🫙"),
    FoodItem(name: "Ketchup", kcalPer100: 112, proteinPer100: 1, carbsPer100: 27, fatPer100: 0, emoji: "🍅"),
    FoodItem(name: "Molho shoyu", kcalPer100: 60, proteinPer100: 6, carbsPer100: 8, fatPer100: 0, emoji: "🫙"),
    FoodItem(name: "Açúcar refinado", kcalPer100: 387, proteinPer100: 0, carbsPer100: 100, fatPer100: 0, emoji: "🍚"),
    FoodItem(name: "Adoçante (stevia)", kcalPer100: 0, proteinPer100: 0, carbsPer100: 0, fatPer100: 0, emoji: "🌿")
]

// MARK: - Biblioteca de exercícios (para montar treinos)

/// Catálogo completo de 130+ exercícios por equipamento/músculo, usado no construtor de treino.
let exerciseLibrary: [Exercise] = [

    // MARK: Peito (20)
    Exercise(name: "Flexão de braço", sets: 4, reps: "15 reps", equipment: .corporal, muscle: "Peito", symbol: "figure.strengthtraining.traditional", instructions: ["Mãos na largura dos ombros, corpo reto.", "Desça o peito até perto do chão e empurre."]),
    Exercise(name: "Flexão diamante", sets: 3, reps: "12 reps", equipment: .corporal, muscle: "Peito e tríceps", symbol: "figure.strengthtraining.traditional", instructions: ["Mãos juntas formando um losango.", "Desça de forma controlada, cotovelos fechados."]),
    Exercise(name: "Flexão declinada", sets: 3, reps: "12 reps", equipment: .corporal, muscle: "Peito inferior", symbol: "figure.strengthtraining.traditional", instructions: ["Pés elevados num banco.", "Desça mantendo o core contraído."]),
    Exercise(name: "Flexão inclinada", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Peito superior", symbol: "figure.strengthtraining.traditional", instructions: ["Mãos em superfície elevada.", "Realize a flexão com amplitude completa."]),
    Exercise(name: "Flexão com palmas", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Peito e explosão", symbol: "figure.highintensity.intervaltraining", instructions: ["Flexão normal e ao subir empurre forte.", "Bata palmas no ar e amortece a queda."]),
    Exercise(name: "Supino com halteres", sets: 4, reps: "10 reps", equipment: .halteres, muscle: "Peito", symbol: "figure.strengthtraining.traditional", instructions: ["Deitado no banco, halteres na linha do peito.", "Empurre para cima até estender os cotovelos."]),
    Exercise(name: "Supino inclinado com halteres", sets: 4, reps: "10 reps", equipment: .halteres, muscle: "Peito superior", symbol: "figure.strengthtraining.traditional", instructions: ["Banco inclinado a 30-45 graus.", "Empurre os halteres para cima e levemente para a frente."]),
    Exercise(name: "Supino declinado com halteres", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Peito inferior", symbol: "figure.strengthtraining.traditional", instructions: ["Banco declinado, quadril elevado.", "Empurre os halteres de baixo para cima."]),
    Exercise(name: "Supino reto com barra", sets: 4, reps: "8 reps", equipment: .barra, muscle: "Peito", symbol: "figure.strengthtraining.traditional", instructions: ["Pegada média na barra.", "Desça a barra até tocar o peito e empurre."]),
    Exercise(name: "Supino inclinado com barra", sets: 4, reps: "8 reps", equipment: .barra, muscle: "Peito superior", symbol: "figure.strengthtraining.traditional", instructions: ["Banco inclinado 30-45 graus.", "Controle a descida e exploda na subida."]),
    Exercise(name: "Supino declinado com barra", sets: 3, reps: "10 reps", equipment: .barra, muscle: "Peito inferior", symbol: "figure.strengthtraining.traditional", instructions: ["Pés fixos, banco declinado.", "Mantém lombar no banco durante todo o movimento."]),
    Exercise(name: "Crossover", sets: 3, reps: "12 reps", equipment: .cabo, muscle: "Peito", symbol: "figure.strengthtraining.functional", instructions: ["Polias altas, braços semiflexionados.", "Cruze os braços na frente do peito em arco."]),
    Exercise(name: "Peck deck voador", sets: 3, reps: "15 reps", equipment: .maquina, muscle: "Peito", symbol: "gearshape.2.fill", instructions: ["Cotovelos no suporte da máquina.", "Feche os braços até tocar e volte controlado."]),
    Exercise(name: "Supino na máquina", sets: 3, reps: "12 reps", equipment: .maquina, muscle: "Peito", symbol: "gearshape.2.fill", instructions: ["Ajuste o assento na altura do peito.", "Empurre e controle o retorno."]),
    Exercise(name: "Pullover com halter", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Peito e costas", symbol: "figure.strengthtraining.traditional", instructions: ["Deitado no banco, segure o halter com ambas as mãos.", "Leve o halter atrás da cabeça em arco e retorne."]),
    Exercise(name: "Pullover na polia", sets: 3, reps: "15 reps", equipment: .cabo, muscle: "Peito e costas", symbol: "figure.strengthtraining.functional", instructions: ["Polia alta, corda ou barra.", "Puxe em arco até o quadril mantendo braços semiflexionados."]),
    Exercise(name: "Voador inclinado", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Peito superior", symbol: "figure.strengthtraining.traditional", instructions: ["Banco inclinado, braços abertos.", "Feche os halteres em arco até a frente."]),
    Exercise(name: "Voador reto", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Peito", symbol: "figure.strengthtraining.traditional", instructions: ["Banco plano, braços abertos com leve flexão.", "Aproxime os halteres em arco acima do peito."]),
    Exercise(name: "Mergulho em paralelas", sets: 4, reps: "12 reps", equipment: .corporal, muscle: "Peito e tríceps", symbol: "figure.strengthtraining.functional", instructions: ["Apoio nas paralelas, corpo levemente inclinado.", "Desça até 90 graus e empurre."]),
    Exercise(name: "Supino no Smith", sets: 3, reps: "10 reps", equipment: .smith, muscle: "Peito", symbol: "square.split.2x1.fill", instructions: ["Barra guiada, banco plano.", "Controle o movimento sem travar a barra."]),

    // MARK: Costas (20)
    Exercise(name: "Remada curvada com barra", sets: 4, reps: "10 reps", equipment: .barra, muscle: "Costas", symbol: "figure.rower", instructions: ["Tronco inclinado, coluna neutra.", "Puxe a barra ao umbigo aproximando as escápulas."]),
    Exercise(name: "Remada unilateral com halter", sets: 4, reps: "12 cada", equipment: .halteres, muscle: "Costas", symbol: "figure.rower", instructions: ["Apoie a mão e o joelho no banco.", "Puxe o halter ao quadril contraindo as costas."]),
    Exercise(name: "Remada cavalinho", sets: 3, reps: "10 reps", equipment: .barra, muscle: "Costas média", symbol: "figure.rower", instructions: ["Incline-se mais que 90 graus.", "Puxe a barra até o peito."]),
    Exercise(name: "Remada sentada na polia", sets: 4, reps: "12 reps", equipment: .cabo, muscle: "Costas", symbol: "figure.rower", instructions: ["Sentado, peço neutro, puxe ao abdômen.", "Controle o retorno mantendo a coluna ereta."]),
    Exercise(name: "Puxada alta pegada aberta", sets: 4, reps: "12 reps", equipment: .cabo, muscle: "Costas", symbol: "figure.strengthtraining.functional", instructions: ["Pegada pronada mais larga que os ombros.", "Puxe a barra até a clavícula."]),
    Exercise(name: "Puxada alta pegada fechada", sets: 4, reps: "12 reps", equipment: .cabo, muscle: "Costas", symbol: "figure.strengthtraining.functional", instructions: ["Pegada supinada na largura dos ombros.", "Puxe a barra até o peito."]),
    Exercise(name: "Puxada alta neutro", sets: 3, reps: "12 reps", equipment: .cabo, muscle: "Costas", symbol: "figure.strengthtraining.functional", instructions: ["Pegada neutra paralela.", "Puxe ao peito contraindo o lat."]),
    Exercise(name: "Levantamento terra", sets: 4, reps: "6 reps", equipment: .barra, muscle: "Costas e posterior", symbol: "figure.strengthtraining.functional", instructions: ["Coluna neutra, quadril atrás.", "Estenda quadril e joelhos simultaneamente."]),
    Exercise(name: "Barra fixa", sets: 4, reps: "max reps", equipment: .corporal, muscle: "Costas e bíceps", symbol: "figure.strengthtraining.functional", instructions: ["Pegada pronada mais larga que os ombros.", "Puxe o peito até a barra."]),
    Exercise(name: "Barra fixa pegada inversa", sets: 3, reps: "max reps", equipment: .corporal, muscle: "Costas e bíceps", symbol: "figure.strengthtraining.functional", instructions: ["Pegada supinada.", "Puxe até o queixo ultrapassar a barra."]),
    Exercise(name: "Remada na máquina", sets: 3, reps: "12 reps", equipment: .maquina, muscle: "Costas", symbol: "gearshape.2.fill", instructions: ["Peito apoiado no suporte.", "Puxe as alças ao abdômen."]),
    Exercise(name: "Levantamento terra romeno", sets: 4, reps: "10 reps", equipment: .barra, muscle: "Posterior e costas", symbol: "figure.strengthtraining.functional", instructions: ["Joelhos levemente flexionados.", "Desça a barra pelas pernas até sentir o alongamento."]),
    Exercise(name: "Boa manhã", sets: 3, reps: "12 reps", equipment: .barra, muscle: "Lombar e isquiotibiais", symbol: "figure.strengthtraining.functional", instructions: ["Barra nos trapézios.", "Incline o tronco até quase paralelo ao chão e retorne."]),
    Exercise(name: "Hiperextenção", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Lombar", symbol: "figure.core.training", instructions: ["Deitado de bruços no aparelho, quadril no suporte.", "Eleve o tronco até ficar alinhado com as pernas."]),
    Exercise(name: "Remada alta com barra", sets: 3, reps: "12 reps", equipment: .barra, muscle: "Trapézio e ombros", symbol: "figure.rower", instructions: ["Pegada próxima ao centro.", "Puxe a barra até o queixo com cotovelos para fora."]),
    Exercise(name: "Face pull", sets: 3, reps: "15 reps", equipment: .cabo, muscle: "Trapézio e manguito", symbol: "figure.strengthtraining.functional", instructions: ["Polia alta, corda com dois punhos.", "Puxe até a frente do rosto abrindo os cotovelos."]),
    Exercise(name: "Superman", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Lombar", symbol: "figure.core.training", instructions: ["Deitado de bruços, braços estendidos.", "Eleve braços e pernas ao mesmo tempo."]),
    Exercise(name: "Remada Yates", sets: 4, reps: "10 reps", equipment: .barra, muscle: "Costas média", symbol: "figure.rower", instructions: ["Tronco quase ereto, pegada supinada.", "Puxe a barra ao umbigo."]),
    Exercise(name: "Pullover na máquina", sets: 3, reps: "12 reps", equipment: .maquina, muscle: "Lat e peito", symbol: "gearshape.2.fill", instructions: ["Cotovelos no suporte curvo.", "Puxe em arco até o quadril."]),
    Exercise(name: "Serrote com halter", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Lat e romboides", symbol: "figure.rower", instructions: ["Apoio unilateral no banco.", "Puxe o halter ao quadril mantendo cotovelo junto ao tronco."]),

    // MARK: Pernas (25)
    Exercise(name: "Agachamento livre", sets: 4, reps: "20 reps", equipment: .corporal, muscle: "Pernas", symbol: "figure.cross.training", instructions: ["Pés na largura dos ombros.", "Desça até as coxas paralelas ao chão."]),
    Exercise(name: "Agachamento com barra", sets: 4, reps: "10 reps", equipment: .barra, muscle: "Pernas e glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Barra nos trapézios, tronco firme.", "Desça e suba empurrando o chão."]),
    Exercise(name: "Agachamento goblet", sets: 3, reps: "15 reps", equipment: .kettlebell, muscle: "Pernas", symbol: "figure.cross.training", instructions: ["Segure o kettlebell junto ao peito.", "Agache profundo mantendo o tronco ereto."]),
    Exercise(name: "Agachamento no Smith", sets: 4, reps: "12 reps", equipment: .smith, muscle: "Pernas", symbol: "square.split.2x1.fill", instructions: ["Barra guiada, coloque os pés à frente.", "Desça controlado e suba sem trancar."]),
    Exercise(name: "Agachamento sumô", sets: 4, reps: "15 reps", equipment: .barra, muscle: "Adutores e glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Pés bem afastados, bico de pé para fora.", "Desça mantendo o tronco ereto."]),
    Exercise(name: "Agachamento búlgáro", sets: 3, reps: "10 cada", equipment: .corporal, muscle: "Quadríceps e glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Pé traseiro apoiado no banco.", "Desça o joelho de trás em direção ao chão."]),
    Exercise(name: "Afundo com halteres", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Pernas e glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Passo à frente, halteres ao lado do corpo.", "Desça o joelho de trás até o chão."]),
    Exercise(name: "Afundo com barra", sets: 3, reps: "12 cada", equipment: .barra, muscle: "Pernas e glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Barra nos trapézios.", "Passo à frente e desça controlado."]),
    Exercise(name: "Agachamento pistol", sets: 3, reps: "8 cada", equipment: .corporal, muscle: "Quadríceps e equilíbrio", symbol: "figure.cross.training", instructions: ["Em pé numa perna só.", "Desça lentamente dobrando o joelho de apoio."]),
    Exercise(name: "Leg press 45", sets: 4, reps: "12 reps", equipment: .maquina, muscle: "Pernas", symbol: "figure.strengthtraining.functional", instructions: ["Pés na plataforma na largura dos ombros.", "Empurre sem travar os joelhos no final."]),
    Exercise(name: "Cadeira extensora", sets: 3, reps: "15 reps", equipment: .maquina, muscle: "Quadríceps", symbol: "gearshape.2.fill", instructions: ["Ajuste o suporte na frente dos tornozelos.", "Estenda as pernas com controle."]),
    Exercise(name: "Mesa flexora", sets: 4, reps: "12 reps", equipment: .maquina, muscle: "Isquiotibiais", symbol: "gearshape.2.fill", instructions: ["Deitado de bruços, suporte atrás dos tornozelos.", "Flexione os joelhos trazendo o calcanhar ao glúteo."]),
    Exercise(name: "Stiff com halteres", sets: 4, reps: "10 reps", equipment: .halteres, muscle: "Isquiotibiais", symbol: "figure.strengthtraining.functional", instructions: ["Joelhos levemente flexionados.", "Incline o tronco descendo os halteres pelas pernas."]),
    Exercise(name: "Stiff com barra", sets: 4, reps: "8 reps", equipment: .barra, muscle: "Isquiotibiais", symbol: "figure.strengthtraining.functional", instructions: ["Pegada pronada, joelhos semi-flexionados.", "Desça a barra controlando o alongamento."]),
    Exercise(name: "Panturrilha em pé", sets: 4, reps: "20 reps", equipment: .corporal, muscle: "Panturrilha", symbol: "figure.walk", instructions: ["Em pé, suba na ponta dos pés lentamente.", "Desça até sentir o alongamento."]),
    Exercise(name: "Panturrilha no aparelho", sets: 4, reps: "20 reps", equipment: .maquina, muscle: "Panturrilha", symbol: "gearshape.2.fill", instructions: ["Peso nos ombros, ponta dos pés na plataforma.", "Suba completamente e desça com controle."]),
    Exercise(name: "Panturrilha sentado", sets: 3, reps: "20 reps", equipment: .maquina, muscle: "Sóleo", symbol: "gearshape.2.fill", instructions: ["Sentado com joelhos a 90 graus, peso nos joelhos.", "Suba na ponta dos pés lentamente."]),
    Exercise(name: "Hack squat", sets: 4, reps: "10 reps", equipment: .maquina, muscle: "Quadríceps", symbol: "gearshape.2.fill", instructions: ["Costas apoiadas na máquina, pés à frente.", "Desça até 90 graus e empurre."]),
    Exercise(name: "Step up", sets: 3, reps: "12 cada", equipment: .corporal, muscle: "Pernas e glúteos", symbol: "figure.cross.training", instructions: ["Suba num banco ou step com uma perna.", "Alterne as pernas no ritmo."]),
    Exercise(name: "Passada lateral", sets: 3, reps: "12 cada", equipment: .corporal, muscle: "Adutores e abdutores", symbol: "figure.cross.training", instructions: ["Em pé, dê um grande passo lateral.", "Agache sobre a perna que dá o passo."]),
    Exercise(name: "Cadeira adutora", sets: 3, reps: "15 reps", equipment: .maquina, muscle: "Adutores", symbol: "gearshape.2.fill", instructions: ["Sentado, pernas abertas no suporte.", "Feche as pernas vencendo a resistência."]),
    Exercise(name: "Cadeira abdutora", sets: 3, reps: "15 reps", equipment: .maquina, muscle: "Abdutores", symbol: "gearshape.2.fill", instructions: ["Sentado, pernas unidas no suporte.", "Abra as pernas vencendo a resistência."]),
    Exercise(name: "Agachamento sumô com halter", sets: 3, reps: "15 reps", equipment: .halteres, muscle: "Adutores e glúteos", symbol: "figure.cross.training", instructions: ["Segure um halter com as duas mãos ao centro.", "Agache com os pés bem afastados."]),
    Exercise(name: "Afundo reverso", sets: 3, reps: "12 cada", equipment: .corporal, muscle: "Pernas e glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Passo para trás.", "Desça o joelho de trás em direção ao chão."]),
    Exercise(name: "Leg press unilateral", sets: 3, reps: "10 cada", equipment: .maquina, muscle: "Pernas unilateral", symbol: "gearshape.2.fill", instructions: ["Uma perna na plataforma.", "Empurre sem trancar o joelho no final."]),

    // MARK: Ombros (15)
    Exercise(name: "Desenvolvimento com halteres", sets: 4, reps: "10 reps", equipment: .halteres, muscle: "Ombros", symbol: "figure.strengthtraining.traditional", instructions: ["Halteres na altura dos ombros.", "Empurre para cima até estender os cotovelos."]),
    Exercise(name: "Desenvolvimento Arnold", sets: 3, reps: "10 reps", equipment: .halteres, muscle: "Ombros", symbol: "figure.strengthtraining.traditional", instructions: ["Comece com halteres na frente, palmas para dentro.", "Gire os punhos para fora enquanto sobe."]),
    Exercise(name: "Desenvolvimento militar com barra", sets: 4, reps: "8 reps", equipment: .barra, muscle: "Ombros", symbol: "figure.strengthtraining.traditional", instructions: ["Em pé, barra na frente na altura dos ombros.", "Empurre acima da cabeça sem arquear a lombar."]),
    Exercise(name: "Desenvolvimento na máquina", sets: 3, reps: "12 reps", equipment: .maquina, muscle: "Ombros", symbol: "gearshape.2.fill", instructions: ["Ajuste o assento, mãos nos puxadores.", "Empurre para cima e controle o retorno."]),
    Exercise(name: "Elevação lateral com halteres", sets: 3, reps: "15 reps", equipment: .halteres, muscle: "Deltoide lateral", symbol: "dumbbell.fill", instructions: ["Braços ao lado com leve flexão de cotovelo.", "Eleve até a linha dos ombros."]),
    Exercise(name: "Elevação lateral na polia", sets: 3, reps: "15 reps", equipment: .cabo, muscle: "Deltoide lateral", symbol: "figure.strengthtraining.functional", instructions: ["Polia baixa, braço semi-flexionado.", "Puxe em arco até a linha dos ombros."]),
    Exercise(name: "Elevação frontal com halteres", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Deltoide anterior", symbol: "dumbbell.fill", instructions: ["Alternado ou simultâneo.", "Eleve os braços até a altura dos ombros."]),
    Exercise(name: "Elevação frontal com barra", sets: 3, reps: "12 reps", equipment: .barra, muscle: "Deltoide anterior", symbol: "figure.strengthtraining.traditional", instructions: ["Pegada média, barra à frente do corpo.", "Eleve até os ombros e controle a descida."]),
    Exercise(name: "Encolhimento de ombros com halteres", sets: 4, reps: "15 reps", equipment: .halteres, muscle: "Trapézio", symbol: "dumbbell.fill", instructions: ["Halteres ao lado do corpo.", "Encolha os ombros sem dobrar os cotovelos."]),
    Exercise(name: "Encolhimento com barra", sets: 4, reps: "15 reps", equipment: .barra, muscle: "Trapézio", symbol: "figure.strengthtraining.traditional", instructions: ["Barra à frente, pegada pronada.", "Eleve os ombros sem dobrar os cotovelos."]),
    Exercise(name: "Remada alta com barra estreita", sets: 3, reps: "12 reps", equipment: .barra, muscle: "Trapézio e ombros", symbol: "figure.rower", instructions: ["Pegada próxima, barra à frente.", "Puxe a barra até o queixo, cotovelos para fora."]),
    Exercise(name: "Desenvolvimento unilateral", sets: 3, reps: "10 cada", equipment: .halteres, muscle: "Ombros", symbol: "dumbbell.fill", instructions: ["Um halter de cada vez.", "Estabilize o core e empurre acima da cabeça."]),
    Exercise(name: "Rotação externa com cabo", sets: 3, reps: "15 cada", equipment: .cabo, muscle: "Manguito rotador", symbol: "figure.strengthtraining.functional", instructions: ["Cotovelo junto ao tronco a 90 graus.", "Gire o antebraço para fora da linha do corpo."]),
    Exercise(name: "Rotação interna com cabo", sets: 3, reps: "15 cada", equipment: .cabo, muscle: "Manguito rotador", symbol: "figure.strengthtraining.functional", instructions: ["Cotovelo junto ao tronco a 90 graus.", "Gire o antebraço em direção ao corpo."]),
    Exercise(name: "Elevação lateral inclinada", sets: 3, reps: "15 reps", equipment: .halteres, muscle: "Deltoide posterior", symbol: "dumbbell.fill", instructions: ["Incline o tronco a 45 graus.", "Eleve os braços lateralmente."]),

    // MARK: Biceps (12)
    Exercise(name: "Rosca direta com barra", sets: 4, reps: "10 reps", equipment: .barra, muscle: "Bíceps", symbol: "dumbbell.fill", instructions: ["Cotovelos fixos ao tronco.", "Flexione trazendo a barra aos ombros."]),
    Exercise(name: "Rosca direta com halteres", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Bíceps", symbol: "dumbbell.fill", instructions: ["Cotovelos fixos ao lado do corpo.", "Flexione levando o halter ao ombro."]),
    Exercise(name: "Rosca alternada", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Bíceps", symbol: "dumbbell.fill", instructions: ["Alterne os braços um de cada vez.", "Gire o punho (supinação) ao subir."]),
    Exercise(name: "Rosca martelo", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Bíceps e braquial", symbol: "dumbbell.fill", instructions: ["Punho neutro (polegar para cima).", "Flexione sem girar o punho."]),
    Exercise(name: "Rosca concentrada", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Bíceps", symbol: "dumbbell.fill", instructions: ["Sentado, cotovelo apoiado na coxa.", "Flexione o antebraço completamente."]),
    Exercise(name: "Rosca Scott", sets: 3, reps: "10 reps", equipment: .barra, muscle: "Bíceps", symbol: "figure.strengthtraining.traditional", instructions: ["Cotovelos apoiados no banco inclinado.", "Flexione completamente e desça com controle."]),
    Exercise(name: "Rosca no cabo", sets: 3, reps: "15 reps", equipment: .cabo, muscle: "Bíceps", symbol: "figure.strengthtraining.functional", instructions: ["Polia baixa, barra reta ou corda.", "Flexione mantendo os cotovelos fixos."]),
    Exercise(name: "Rosca inversa", sets: 3, reps: "12 reps", equipment: .barra, muscle: "Bíceps e antebraço", symbol: "dumbbell.fill", instructions: ["Pegada pronada (palmas para baixo).", "Flexione controlando o retorno."]),
    Exercise(name: "Rosca 21", sets: 3, reps: "21 reps", equipment: .barra, muscle: "Bíceps", symbol: "dumbbell.fill", instructions: ["7 meio inferior, 7 meio superior, 7 completos.", "Sem parar entre as fases."]),
    Exercise(name: "Rosca com elástico", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Bíceps", symbol: "figure.flexibility", instructions: ["Pise no elástico, segure os extremos.", "Flexione os cotovelos como na rosca normal."]),
    Exercise(name: "Rosca aranha", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Bíceps e braquial", symbol: "dumbbell.fill", instructions: ["Tronco inclinado, cotovelos apontados para baixo.", "Flexione subindo os halteres."]),
    Exercise(name: "Chin-up", sets: 4, reps: "max reps", equipment: .corporal, muscle: "Bíceps e costas", symbol: "figure.strengthtraining.functional", instructions: ["Barra fixa com pegada supinada.", "Puxe até o queixo passar a barra."]),

    // MARK: Triceps (12)
    Exercise(name: "Tríceps na polia corda", sets: 4, reps: "15 reps", equipment: .cabo, muscle: "Tríceps", symbol: "figure.strengthtraining.functional", instructions: ["Cotovelos fixos ao tronco, polia alta.", "Estenda puxando a corda para baixo e abrindo no final."]),
    Exercise(name: "Tríceps na polia barra", sets: 4, reps: "15 reps", equipment: .cabo, muscle: "Tríceps", symbol: "figure.strengthtraining.functional", instructions: ["Cotovelos fixos, polia alta, barra reta.", "Empurre a barra para baixo até estender."]),
    Exercise(name: "Tríceps testa", sets: 3, reps: "10 reps", equipment: .barra, muscle: "Tríceps", symbol: "figure.strengthtraining.traditional", instructions: ["Deitado no banco, barra acima do peito.", "Flexione os cotovelos descendo a barra rumo à testa."]),
    Exercise(name: "Tríceps testa com halteres", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Tríceps", symbol: "figure.strengthtraining.traditional", instructions: ["Halteres acima do peito.", "Flexione os cotovelos descendo os halteres aos lados da cabeça."]),
    Exercise(name: "Tríceps coice", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Tríceps", symbol: "dumbbell.fill", instructions: ["Tronco inclinado, cotovelo a 90 graus.", "Estenda o antebraço para trás."]),
    Exercise(name: "Tríceps banco", sets: 4, reps: "15 reps", equipment: .corporal, muscle: "Tríceps", symbol: "figure.strengthtraining.functional", instructions: ["Mãos apoiadas no banco atrás, pés à frente.", "Desça dobrando os cotovelos e empurre de volta."]),
    Exercise(name: "Tríceps francês", sets: 3, reps: "10 reps", equipment: .barra, muscle: "Tríceps", symbol: "figure.strengthtraining.traditional", instructions: ["Em pé ou sentado, barra acima da cabeça.", "Flexione os cotovelos baixando a barra atrás da cabeça."]),
    Exercise(name: "Tríceps kickback", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Tríceps", symbol: "dumbbell.fill", instructions: ["Tronco inclinado, cotovelo a 90 graus.", "Estenda o antebraço para trás completamente."]),
    Exercise(name: "Paralelas foco tríceps", sets: 4, reps: "12 reps", equipment: .corporal, muscle: "Tríceps e peito", symbol: "figure.strengthtraining.functional", instructions: ["Tronco ereto para focar o tríceps.", "Desça até 90 graus e empurre."]),
    Exercise(name: "Extensão de tríceps overhead", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Tríceps", symbol: "dumbbell.fill", instructions: ["Segure um halter com as duas mãos acima da cabeça.", "Flexione os cotovelos e retorne."]),
    Exercise(name: "Tríceps unilateral na polia", sets: 3, reps: "15 cada", equipment: .cabo, muscle: "Tríceps", symbol: "figure.strengthtraining.functional", instructions: ["Um braço por vez, polia alta.", "Estenda completamente e controle o retorno."]),
    Exercise(name: "Mergulho entre bancos", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Tríceps", symbol: "figure.strengthtraining.functional", instructions: ["Mãos num banco, pés no outro.", "Desça dobrando os cotovelos e empurre."]),

    // MARK: Core (15)
    Exercise(name: "Prancha", sets: 4, reps: "45 s", equipment: .corporal, muscle: "Core", symbol: "figure.core.training", instructions: ["Antebraços e ponta dos pés apoiados.", "Corpo reto, core e glúteos contraídos."]),
    Exercise(name: "Prancha lateral", sets: 3, reps: "30 s cada", equipment: .corporal, muscle: "Oblíquos", symbol: "figure.core.training", instructions: ["Apoio no antebraço lateral e pé inferior.", "Eleve o quadril formando linha reta."]),
    Exercise(name: "Abdominal crunch", sets: 4, reps: "20 reps", equipment: .corporal, muscle: "Abdômen", symbol: "figure.core.training", instructions: ["Joelhos flexionados, mãos na nuca.", "Contraia o abdômen subindo o tronco."]),
    Exercise(name: "Abdominal bicicleta", sets: 3, reps: "20 reps", equipment: .corporal, muscle: "Abdômen e oblíquos", symbol: "figure.core.training", instructions: ["Deitado, joelhos levantados.", "Leve o cotovelo ao joelho oposto alternando."]),
    Exercise(name: "Abdominal remador", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Abdômen", symbol: "figure.core.training", instructions: ["Sentado, pernas estendidas e elevadas.", "Traga os joelhos ao peito e retorne."]),
    Exercise(name: "Russian twist", sets: 3, reps: "20 reps", equipment: .corporal, muscle: "Oblíquos", symbol: "figure.core.training", instructions: ["Sentado com tronco inclinado.", "Gire o tronco de um lado ao outro."]),
    Exercise(name: "Mountain climbers", sets: 4, reps: "30 s", equipment: .corporal, muscle: "Core e cardio", symbol: "figure.run", instructions: ["Posição de prancha alta.", "Leve os joelhos ao peito alternando rapidamente."]),
    Exercise(name: "Elevação de pernas deitado", sets: 4, reps: "15 reps", equipment: .corporal, muscle: "Abdômen inferior", symbol: "figure.core.training", instructions: ["Deitado, mãos sob os glúteos.", "Eleve as pernas a 90 graus e desça sem tocar o chão."]),
    Exercise(name: "Abdominal canivete", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Abdômen", symbol: "figure.core.training", instructions: ["Deitado, braços e pernas estendidos.", "Suba braços e pernas simultaneamente buscando os pés."]),
    Exercise(name: "Rollout com roda", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Core", symbol: "figure.core.training", instructions: ["Ajoelhado, mãos na roda abdominal.", "Role para frente controlando o abdômen."]),
    Exercise(name: "Abdominal na polia", sets: 3, reps: "15 reps", equipment: .cabo, muscle: "Abdômen", symbol: "figure.strengthtraining.functional", instructions: ["Ajoelhado, polia alta, corda na nuca.", "Contraia o abdômen flexionando o tronco."]),
    Exercise(name: "Dead bug", sets: 3, reps: "10 cada", equipment: .corporal, muscle: "Core e estabilidade", symbol: "figure.core.training", instructions: ["Deitado, braços e pernas elevados a 90 graus.", "Estenda um braço e a perna oposta alternando."]),
    Exercise(name: "Hollow hold", sets: 3, reps: "30 s", equipment: .corporal, muscle: "Core", symbol: "figure.core.training", instructions: ["Deitado, braços e pernas levemente elevados.", "Mantenha a posição contraindo o abdômen."]),
    Exercise(name: "Tocada no calcanhar", sets: 3, reps: "20 reps", equipment: .corporal, muscle: "Oblíquos", symbol: "figure.core.training", instructions: ["Deitado com joelhos dobrados.", "Incline de lado tocando o calcanhar alternadamente."]),
    Exercise(name: "Prancha com elevação de braço", sets: 3, reps: "10 cada", equipment: .corporal, muscle: "Core e estabilidade", symbol: "figure.core.training", instructions: ["Prancha alta.", "Eleve um braço de cada vez mantendo o quadril estável."]),

    // MARK: Gluteos (10)
    Exercise(name: "Hip thrust com barra", sets: 4, reps: "12 reps", equipment: .barra, muscle: "Glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Ombros no banco, barra no quadril.", "Eleve o quadril até ficar alinhado com o tronco."]),
    Exercise(name: "Hip thrust com halter", sets: 4, reps: "15 reps", equipment: .halteres, muscle: "Glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Ombros no banco, halter no quadril.", "Contraia os glúteos no topo do movimento."]),
    Exercise(name: "Elevação pélvica", sets: 4, reps: "20 reps", equipment: .corporal, muscle: "Glúteos", symbol: "figure.core.training", instructions: ["Deitado com joelhos flexionados.", "Eleve o quadril contraindo os glúteos."]),
    Exercise(name: "Kickback no cabo", sets: 3, reps: "15 cada", equipment: .cabo, muscle: "Glúteos", symbol: "figure.strengthtraining.functional", instructions: ["Polia baixa, cinto no tornozelo.", "Estenda a perna para trás contraindo o glúteo."]),
    Exercise(name: "Abdução no cabo", sets: 3, reps: "15 cada", equipment: .cabo, muscle: "Glúteos e abdutores", symbol: "figure.strengthtraining.functional", instructions: ["Polia baixa, cinto no tornozelo.", "Afaste a perna lateralmente."]),
    Exercise(name: "Passada com halteres", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Glúteos e pernas", symbol: "figure.strengthtraining.functional", instructions: ["Halteres ao lado, passo largo à frente.", "Desça o joelho de trás ao chão."]),
    Exercise(name: "Agachamento sumô foco glúteo", sets: 4, reps: "15 reps", equipment: .halteres, muscle: "Glúteos e adutores", symbol: "figure.cross.training", instructions: ["Pés muito afastados, ponta para fora.", "Agache profundo contraindo o glúteo."]),
    Exercise(name: "Good morning", sets: 3, reps: "12 reps", equipment: .barra, muscle: "Glúteos e lombar", symbol: "figure.strengthtraining.functional", instructions: ["Barra nos trapézios.", "Incline o tronco para frente dobrando o quadril."]),
    Exercise(name: "Stiff unilateral", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Glúteo e isquiotibiais", symbol: "figure.strengthtraining.functional", instructions: ["Apoio numa perna só, halter na mão oposta.", "Incline o tronco descendo o halter."]),
    Exercise(name: "Elevação de perna no solo", sets: 3, reps: "20 cada", equipment: .corporal, muscle: "Glúteos", symbol: "figure.core.training", instructions: ["De quatro, perna semiflexionada.", "Eleve o calcanhar para o teto contraindo o glúteo."]),

    // MARK: Cardio (10)
    Exercise(name: "Caminhada em esteira", sets: 1, reps: "25 min", equipment: .maquina, muscle: "Cardio", symbol: "figure.walk", instructions: ["Postura ereta, braços em movimento natural.", "Respire pelo nariz, ritmo constante."]),
    Exercise(name: "Corrida em esteira", sets: 1, reps: "20 min", equipment: .maquina, muscle: "Cardio", symbol: "figure.run", instructions: ["Passada suave, aterrisse no meio do pé.", "Controle a respiração."]),
    Exercise(name: "Bicicleta ergômétrica", sets: 1, reps: "20 min", equipment: .maquina, muscle: "Cardio e pernas", symbol: "figure.outdoor.cycle", instructions: ["Ajuste o selim na altura do quadril.", "Pedale com ritmo moderado a alto."]),
    Exercise(name: "Elíptico", sets: 1, reps: "20 min", equipment: .maquina, muscle: "Cardio", symbol: "figure.elliptical", instructions: ["Use o movimento do braço junto.", "Mantenha postura ereta."]),
    Exercise(name: "Polichinelos", sets: 4, reps: "40 s", equipment: .corporal, muscle: "Cardio", symbol: "figure.mixed.cardio", instructions: ["Comece em pé com pés juntos.", "Salte abrindo pernas e levantando braços."]),
    Exercise(name: "Burpee", sets: 4, reps: "30 s", equipment: .corporal, muscle: "Corpo inteiro", symbol: "figure.highintensity.intervaltraining", instructions: ["Agache, prancha, volta e salte.", "Mantenha o ritmo."]),
    Exercise(name: "Pular corda", sets: 4, reps: "1 min", equipment: .corporal, muscle: "Cardio e panturrilha", symbol: "figure.mixed.cardio", instructions: ["Pulsos girando a corda.", "Aterrisse suave nas pontas dos pés."]),
    Exercise(name: "Agachamento com salto", sets: 4, reps: "15 reps", equipment: .corporal, muscle: "Pernas e cardio", symbol: "figure.cross.training", instructions: ["Agache e exploda para cima num salto.", "Amortece suave ao aterrissar."]),
    Exercise(name: "Sprint 40m", sets: 6, reps: "40 m", equipment: .corporal, muscle: "Cardio e velocidade", symbol: "figure.run", instructions: ["Corrida máxima por 40 metros.", "Descanso de 30s entre tiros."]),
    Exercise(name: "Corrida estacionária", sets: 4, reps: "45 s", equipment: .corporal, muscle: "Cardio", symbol: "figure.run", instructions: ["Corra no lugar elevando os joelhos.", "Braços em movimento de corrida."]),

    // MARK: Funcional (10)
    Exercise(name: "Swing com kettlebell", sets: 4, reps: "20 reps", equipment: .kettlebell, muscle: "Posterior e core", symbol: "figure.cross.training", instructions: ["Quadril para trás, coluna neutra.", "Impulsione o kettlebell até a altura dos ombros."]),
    Exercise(name: "Turkish get-up", sets: 3, reps: "5 cada", equipment: .kettlebell, muscle: "Corpo inteiro", symbol: "figure.cross.training", instructions: ["Deitado com kettlebell estendido acima.", "Levante-se mantendo o braço ereto."]),
    Exercise(name: "Thruster com kettlebell", sets: 4, reps: "10 reps", equipment: .kettlebell, muscle: "Pernas e ombros", symbol: "figure.cross.training", instructions: ["Agache com kettlebell na frente.", "Ao subir, empurre o kettlebell acima da cabeça."]),
    Exercise(name: "Box jump", sets: 4, reps: "10 reps", equipment: .corporal, muscle: "Pernas e explosão", symbol: "figure.cross.training", instructions: ["Salte sobre um caixote ou step.", "Aterrisse com os joelhos levemente flexionados."]),
    Exercise(name: "Slam ball", sets: 4, reps: "15 reps", equipment: .corporal, muscle: "Corpo inteiro", symbol: "figure.cross.training", instructions: ["Eleve a bola acima da cabeça.", "Arremesse com força no chão."]),
    Exercise(name: "Bear crawl", sets: 3, reps: "20 m", equipment: .corporal, muscle: "Core e corpo inteiro", symbol: "figure.cross.training", instructions: ["De quatro, joelhos a 5cm do chão.", "Mova braço e perna opostos em sincronia."]),
    Exercise(name: "Farmer walk", sets: 4, reps: "30 m", equipment: .halteres, muscle: "Core e pegada", symbol: "figure.walk", instructions: ["Halteres pesados ao lado do corpo.", "Caminhe ereto com passos controlados."]),
    Exercise(name: "Battle rope ondas", sets: 4, reps: "30 s", equipment: .cabo, muscle: "Ombros e cardio", symbol: "figure.mixed.cardio", instructions: ["Segure uma ponta da corda em cada mão.", "Crie ondas alternadas ou simultâneas."]),
    Exercise(name: "Clean com kettlebell", sets: 3, reps: "8 cada", equipment: .kettlebell, muscle: "Corpo inteiro", symbol: "figure.cross.training", instructions: ["Inicie como o swing e ao subir recepcione no ombro.", "Mantenha o pulso neutro."]),
    Exercise(name: "Agachamento overhead", sets: 3, reps: "10 reps", equipment: .barra, muscle: "Pernas, core e ombros", symbol: "figure.cross.training", instructions: ["Barra acima da cabeça com braços estendidos.", "Agache mantendo a barra alinhada acima dos pés."]),

    // MARK: Mobilidade e Alongamento (20)
    Exercise(name: "Alongamento de isquiotibiais em pé", sets: 2, reps: "30 s cada", equipment: .corporal, muscle: "Isquiotibiais", symbol: "figure.flexibility", instructions: ["Em pé, apoie o calcanhar numa superfície.", "Incline o tronco para a perna estendida."]),
    Exercise(name: "Alongamento de quadríceps em pé", sets: 2, reps: "30 s cada", equipment: .corporal, muscle: "Quadríceps", symbol: "figure.flexibility", instructions: ["Em pé, dobre o joelho levando o calcanhar ao glúteo.", "Mantenha o quadril reto e apoio firme."]),
    Exercise(name: "Alongamento de panturrilha na parede", sets: 2, reps: "30 s cada", equipment: .corporal, muscle: "Panturrilha", symbol: "figure.flexibility", instructions: ["Apoie as mãos na parede, perna estendida atrás.", "Empurre o calcanhar contra o chão."]),
    Exercise(name: "Alongamento de peitoral na porta", sets: 2, reps: "30 s cada", equipment: .corporal, muscle: "Peito e ombros", symbol: "figure.flexibility", instructions: ["Braços apoiados na moldura da porta.", "Avance o tronco até sentir o alongamento no peito."]),
    Exercise(name: "Abertura de quadril (pigeon pose)", sets: 2, reps: "45 s cada", equipment: .corporal, muscle: "Quadril", symbol: "figure.flexibility", instructions: ["Perna dianteira dobrada a 90 graus no chão.", "Afunde o quadril em direção ao chão."]),
    Exercise(name: "Torção espinhal deitado", sets: 2, reps: "30 s cada", equipment: .corporal, muscle: "Coluna e oblíquos", symbol: "figure.flexibility", instructions: ["Deitado, traga um joelho ao peito.", "Leve o joelho para o lado oposto mantendo os ombros no chão."]),
    Exercise(name: "Passada com rotação de tronco", sets: 3, reps: "8 cada", equipment: .corporal, muscle: "Quadril e torácica", symbol: "figure.flexibility", instructions: ["Posição de passada, mão no chão.", "Gire o braço de cima abrindo o tórax."]),
    Exercise(name: "Cat-cow (gato e vaca)", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Coluna", symbol: "figure.flexibility", instructions: ["De quatro, respire e faça a coluna curvar para cima.", "Exale e deixe a barriga afundar arquivando a lombar."]),
    Exercise(name: "Mobilidade de tornozelo (círculos)", sets: 2, reps: "10 reps cada", equipment: .corporal, muscle: "Tornozelo", symbol: "figure.flexibility", instructions: ["Sentado ou em pé com perna elevada.", "Faça círculos amplos com o pé nos dois sentidos."]),
    Exercise(name: "Mobilidade de ombro (rotação)", sets: 2, reps: "10 reps", equipment: .corporal, muscle: "Ombro", symbol: "figure.flexibility", instructions: ["Braço estendido, faça círculos amplos.", "Alterne para frente e para trás."]),
    Exercise(name: "Corrida com elevação de joelhos (aquecimento)", sets: 2, reps: "30 s", equipment: .corporal, muscle: "Aquecimento", symbol: "figure.run", instructions: ["Corra no lugar elevando os joelhos alto.", "Mantenha o abdômen contraído."]),
    Exercise(name: "Arm circles", sets: 2, reps: "20 reps", equipment: .corporal, muscle: "Ombros — aquecimento", symbol: "figure.flexibility", instructions: ["Braços estendidos lateralmente.", "Faça círculos progressivamente maiores."]),
    Exercise(name: "Leg swings (frente e trás)", sets: 2, reps: "15 cada", equipment: .corporal, muscle: "Quadril", symbol: "figure.flexibility", instructions: ["Apoie-se na parede.", "Balance a perna para frente e para trás em amplitude crescente."]),
    Exercise(name: "Leg swings laterais", sets: 2, reps: "15 cada", equipment: .corporal, muscle: "Adutores e abdutores", symbol: "figure.flexibility", instructions: ["Apoie-se na parede de lado.", "Balance a perna de um lado para o outro."]),
    Exercise(name: "Mobilidade torácica com rolo", sets: 2, reps: "10 reps", equipment: .corporal, muscle: "Coluna torácica", symbol: "figure.flexibility", instructions: ["Rolo de espuma sob a coluna torácica.", "Apoie a cabeça, relax e arquive levemente."]),
    Exercise(name: "World's greatest stretch", sets: 2, reps: "5 cada", equipment: .corporal, muscle: "Corpo todo", symbol: "figure.flexibility", instructions: ["Posição de passada baixa.", "Leve o cotovelo ao chão e depois gire para o teto."]),
    Exercise(name: "Abertura lateral (lateral lunge com pausa)", sets: 2, reps: "8 cada", equipment: .corporal, muscle: "Adutores", symbol: "figure.flexibility", instructions: ["Passo grande lateral, agache sobre a perna flexionada.", "Mantenha a perna oposta estendida."]),
    Exercise(name: "Ponte de glúteo (mobilidade)", sets: 2, reps: "15 reps", equipment: .corporal, muscle: "Glúteos e lombar", symbol: "figure.flexibility", instructions: ["Deitado, pés próximos ao glúteo.", "Eleve o quadril lentamente e desça controlado."]),
    Exercise(name: "Intra-workout stretch: peito", sets: 1, reps: "30 s", equipment: .corporal, muscle: "Peito", symbol: "figure.flexibility", instructions: ["Braços abertos, entrelaçe os dedos atrás das costas.", "Abra o peito e olhe levemente para cima."]),
    Exercise(name: "Respiração diafragmática", sets: 3, reps: "5 ciclos", equipment: .corporal, muscle: "Relaxamento", symbol: "wind", instructions: ["Inspire pelo nariz por 4 s enchendo o abdômen.", "Segure 2 s e expire pela boca por 6 s."]),

    // MARK: Pilates e Yoga (18)
    Exercise(name: "Hundred (Pilates)", sets: 1, reps: "100 batidas", equipment: .corporal, muscle: "Core e respiração", symbol: "figure.core.training", instructions: ["Deitado, pernas a 45 graus, braços batendo.", "Inspire 5 batidas, expire 5 batidas."]),
    Exercise(name: "Roll-up (Pilates)", sets: 3, reps: "8 reps", equipment: .corporal, muscle: "Abdômen e flexibilidade", symbol: "figure.core.training", instructions: ["Deitado, braços acima da cabeça.", "Enrole o corpo subindo vértebra por vértebra."]),
    Exercise(name: "Single leg stretch (Pilates)", sets: 3, reps: "10 cada", equipment: .corporal, muscle: "Core", symbol: "figure.core.training", instructions: ["Deitado, pernas alternadas ao peito.", "Troque as pernas mantendo o crunch."]),
    Exercise(name: "Double leg stretch (Pilates)", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Core", symbol: "figure.core.training", instructions: ["Pernas e braços estendidos ao mesmo tempo.", "Retorne trazendo joelhos e mãos ao peito."]),
    Exercise(name: "Swan (Pilates)", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Extensores da coluna", symbol: "figure.core.training", instructions: ["Deitado de bruços, mãos abaixo dos ombros.", "Estique os braços elevando o tronco suavemente."]),
    Exercise(name: "Side kick (Pilates)", sets: 3, reps: "12 cada", equipment: .corporal, muscle: "Quadril e abdutores", symbol: "figure.core.training", instructions: ["Deitado de lado, perna de cima elevada.", "Chute para frente e para trás controladamente."]),
    Exercise(name: "Teaser (Pilates)", sets: 3, reps: "8 reps", equipment: .corporal, muscle: "Core completo", symbol: "figure.core.training", instructions: ["Deitado, eleve braços e pernas simultaneamente.", "Forme um V equilibrando no cóccix."]),
    Exercise(name: "Saudação ao sol (Yoga)", sets: 3, reps: "5 ciclos", equipment: .corporal, muscle: "Corpo todo", symbol: "figure.flexibility", instructions: ["Sequência: postura da montanha, mergulho, prancha, cobra, cachorro olhando para baixo.", "Mova com a respiração, 1 movimento por ciclo."]),
    Exercise(name: "Guerreiro I (Yoga)", sets: 2, reps: "45 s cada", equipment: .corporal, muscle: "Pernas e quadril", symbol: "figure.flexibility", instructions: ["Passada longa, perna traseira estendida.", "Braços acima da cabeça, olhe para a frente."]),
    Exercise(name: "Guerreiro II (Yoga)", sets: 2, reps: "45 s cada", equipment: .corporal, muscle: "Pernas e ombros", symbol: "figure.flexibility", instructions: ["Pé dianteiro a 90 graus, braços abertos.", "Olhe para a ponta dos dedos da mão dianteira."]),
    Exercise(name: "Postura da árvore (Yoga)", sets: 2, reps: "45 s cada", equipment: .corporal, muscle: "Equilíbrio e core", symbol: "figure.flexibility", instructions: ["Em pé numa perna, pé oposto na coxa.", "Mãos juntas ao peito ou acima da cabeça."]),
    Exercise(name: "Postura da criança (Yoga)", sets: 1, reps: "60 s", equipment: .corporal, muscle: "Lombar e quadril", symbol: "figure.flexibility", instructions: ["Sente sobre os calcanhares, braços estendidos.", "Relaxe o tronco no chão."]),
    Exercise(name: "Postura do cachorro (Yoga)", sets: 3, reps: "30 s", equipment: .corporal, muscle: "Isquiotibiais e panturrilha", symbol: "figure.flexibility", instructions: ["Mãos e pés no chão, quadril elevado.", "Pressione os calcanhares ao chão."]),
    Exercise(name: "Postura do barco (Yoga)", sets: 3, reps: "30 s", equipment: .corporal, muscle: "Core", symbol: "figure.core.training", instructions: ["Sentado, equilibre no cóccix.", "Pernas e tronco formam um V."]),
    Exercise(name: "Postura da cobra (Yoga)", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Extensores e peito", symbol: "figure.flexibility", instructions: ["Deitado de bruços, palmas sob os ombros.", "Estique os cotovelos erguendo o peito."]),
    Exercise(name: "Torção sentada (Yoga)", sets: 2, reps: "30 s cada", equipment: .corporal, muscle: "Coluna e oblíquos", symbol: "figure.flexibility", instructions: ["Sentado com pernas cruzadas.", "Gire o tronco apoiando a mão oposta no joelho."]),
    Exercise(name: "Respiração ujjayi (Yoga)", sets: 1, reps: "5 min", equipment: .corporal, muscle: "Relaxamento e foco", symbol: "wind", instructions: ["Inspire e expire pelo nariz com som suave na garganta.", "Mantenha ritmo lento e constante."]),
    Exercise(name: "Prancha do lado (Side plank) — Pilates", sets: 3, reps: "30 s cada", equipment: .corporal, muscle: "Oblíquos e estabilidade", symbol: "figure.core.training", instructions: ["Apoio na mão, corpo em linha reta lateral.", "Eleve o quadril e mantenha."]),

    // MARK: HIIT (15)
    Exercise(name: "Tabata — agachamento com salto", sets: 8, reps: "20 s on / 10 s off", equipment: .corporal, muscle: "Pernas e cardio", symbol: "figure.highintensity.intervaltraining", instructions: ["20 segundos de agachamento com salto.", "10 segundos de descanso. Repita 8 vezes."]),
    Exercise(name: "Tabata — burpee", sets: 8, reps: "20 s on / 10 s off", equipment: .corporal, muscle: "Corpo todo", symbol: "figure.highintensity.intervaltraining", instructions: ["20 segundos de burpees completos.", "10 segundos de descanso. Repita 8 vezes."]),
    Exercise(name: "Tabata — mountain climber", sets: 8, reps: "20 s on / 10 s off", equipment: .corporal, muscle: "Core e cardio", symbol: "figure.highintensity.intervaltraining", instructions: ["20 segundos de mountain climbers rápidos.", "10 segundos de descanso."]),
    Exercise(name: "Corrida de escada (stair run)", sets: 6, reps: "2 subidas", equipment: .corporal, muscle: "Cardio e pernas", symbol: "figure.stair.stepper", instructions: ["Suba a escada em corrida o mais rápido possível.", "Desça andando para o descanso."]),
    Exercise(name: "Shuttle run (ida e volta 20m)", sets: 8, reps: "20 m", equipment: .corporal, muscle: "Cardio e aceleração", symbol: "figure.run", instructions: ["Corra 10m, toque o chão, volte correndo.", "Foco na desaceleração e mudança de direção."]),
    Exercise(name: "Power clean (barra)", sets: 5, reps: "5 reps", equipment: .barra, muscle: "Corpo todo — explosão", symbol: "figure.strengthtraining.functional", instructions: ["Levantamento terra explosivo com recepção nos ombros.", "Mantenha o core rígido durante todo o movimento."]),
    Exercise(name: "Snatch com kettlebell", sets: 4, reps: "8 cada", equipment: .kettlebell, muscle: "Corpo todo — potência", symbol: "figure.cross.training", instructions: ["Swing explosivo levando o kettlebell acima da cabeça.", "Braço estendido no topo, descida controlada."]),
    Exercise(name: "Push press (barra)", sets: 4, reps: "8 reps", equipment: .barra, muscle: "Ombros e pernas — explosão", symbol: "figure.strengthtraining.traditional", instructions: ["Barra nos ombros, leve semiflexão de joelhos.", "Use o impulso das pernas para empurrar a barra acima."]),
    Exercise(name: "Jumping lunges", sets: 4, reps: "20 reps", equipment: .corporal, muscle: "Pernas e cardio", symbol: "figure.highintensity.intervaltraining", instructions: ["Passada e salto trocando as pernas no ar.", "Amortece suave ao pousar."]),
    Exercise(name: "Bear plank shoulder tap", sets: 3, reps: "20 reps", equipment: .corporal, muscle: "Core e estabilidade", symbol: "figure.core.training", instructions: ["De quatro com joelhos a 5cm do chão.", "Toque o ombro oposto alternando sem balançar o quadril."]),
    Exercise(name: "Salto lateral sobre cone", sets: 5, reps: "10 cada", equipment: .corporal, muscle: "Glúteos e explosão", symbol: "figure.cross.training", instructions: ["Salte lateralmente sobre um obstáculo baixo.", "Aterrisse suave e salte imediatamente para o outro lado."]),
    Exercise(name: "Push-up to mountain climber", sets: 4, reps: "10 reps", equipment: .corporal, muscle: "Peito, core e cardio", symbol: "figure.highintensity.intervaltraining", instructions: ["Flexão completa.", "No topo, faça 2 mountain climbers e repita."]),
    Exercise(name: "Star jump", sets: 4, reps: "15 reps", equipment: .corporal, muscle: "Cardio e corpo todo", symbol: "figure.highintensity.intervaltraining", instructions: ["Agache e salte abrindo braços e pernas.", "Aterrisse em agachamento."]),
    Exercise(name: "Plank jack", sets: 4, reps: "20 reps", equipment: .corporal, muscle: "Core e cardio", symbol: "figure.core.training", instructions: ["Posição de prancha alta.", "Abra e feche as pernas como um polichinelo."]),
    Exercise(name: "Lateral shuffle (20m)", sets: 6, reps: "20 m", equipment: .corporal, muscle: "Adutores, abdutores e cardio", symbol: "figure.run", instructions: ["Posição agachada baixa.", "Mova-se lateralmente com passos curtos rápidos."]),

    // MARK: Elástico (15)
    Exercise(name: "Agachamento com elástico", sets: 3, reps: "20 reps", equipment: .elastico, muscle: "Pernas e glúteos", symbol: "figure.flexibility", instructions: ["Pise no elástico, segure na altura dos ombros.", "Agache e suba estendendo completamente."]),
    Exercise(name: "Desenvolvimento com elástico", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Ombros", symbol: "figure.flexibility", instructions: ["Pise no elástico, segure na altura dos ombros.", "Empurre acima da cabeça e controle a descida."]),
    Exercise(name: "Remada com elástico", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Costas", symbol: "figure.flexibility", instructions: ["Prenda o elástico à frente, segure as extremidades.", "Puxe até o umbigo aproximando as escápulas."]),
    Exercise(name: "Abdução de quadril com elástico", sets: 3, reps: "20 cada", equipment: .elastico, muscle: "Glúteos e abdutores", symbol: "figure.flexibility", instructions: ["Elástico acima dos joelhos.", "Afaste as pernas vencendo a resistência."]),
    Exercise(name: "Caminhar de lado com elástico (crab walk)", sets: 3, reps: "15 m cada", equipment: .elastico, muscle: "Glúteos e abdutores", symbol: "figure.flexibility", instructions: ["Elástico nos tornozelos, posição agachada.", "Caminhe lateralmente mantendo a tensão."]),
    Exercise(name: "Kickback com elástico", sets: 3, reps: "15 cada", equipment: .elastico, muscle: "Glúteos", symbol: "figure.flexibility", instructions: ["Prenda o elástico no tornozelo.", "Estenda a perna para trás contraindo o glúteo."]),
    Exercise(name: "Tríceps com elástico (overhead)", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Tríceps", symbol: "figure.flexibility", instructions: ["Pise no elástico, segure atrás da cabeça.", "Estenda os cotovelos acima da cabeça."]),
    Exercise(name: "Rosca bíceps com elástico", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Bíceps", symbol: "figure.flexibility", instructions: ["Pise no elástico, segure as extremidades.", "Flexione os cotovelos até os ombros."]),
    Exercise(name: "Elevação lateral com elástico", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Deltoide lateral", symbol: "figure.flexibility", instructions: ["Pise no elástico com um pé.", "Eleve o braço oposto até a linha dos ombros."]),
    Exercise(name: "Chest press com elástico", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Peito", symbol: "figure.flexibility", instructions: ["Prenda o elástico nas costas, segure nas extremidades.", "Empurre à frente como num supino em pé."]),
    Exercise(name: "Stiff com elástico", sets: 3, reps: "12 reps", equipment: .elastico, muscle: "Isquiotibiais", symbol: "figure.flexibility", instructions: ["Pise no elástico, incline o tronco à frente.", "Suba estendendo o quadril."]),
    Exercise(name: "Hip thrust com elástico", sets: 4, reps: "15 reps", equipment: .elastico, muscle: "Glúteos", symbol: "figure.flexibility", instructions: ["Elástico acima dos joelhos, deitado.", "Eleve o quadril e abra levemente os joelhos."]),
    Exercise(name: "Pull apart com elástico", sets: 3, reps: "20 reps", equipment: .elastico, muscle: "Deltoide posterior e trapézio", symbol: "figure.flexibility", instructions: ["Segure o elástico à frente com ambas as mãos.", "Puxe abrindo os braços lateralmente."]),
    Exercise(name: "Agachamento com chute com elástico", sets: 3, reps: "12 cada", equipment: .elastico, muscle: "Pernas e glúteos", symbol: "figure.flexibility", instructions: ["Elástico nos tornozelos.", "Agache e ao subir chute lateralmente."]),
    Exercise(name: "Corrida resistida com elástico", sets: 5, reps: "20 m", equipment: .elastico, muscle: "Cardio e posterior", symbol: "figure.flexibility", instructions: ["Parceiro segura o elástico atrás.", "Corra resistindo à tensão por 20 metros."]),

    // MARK: Antebraço e Pegada (10)
    Exercise(name: "Rosca de punho com barra (palma para cima)", sets: 3, reps: "20 reps", equipment: .barra, muscle: "Antebraço flexor", symbol: "dumbbell.fill", instructions: ["Sentado, antebraços nos joelhos, barra na ponta dos dedos.", "Flex ione os punhos subindo."]),
    Exercise(name: "Rosca de punho reversa (palma para baixo)", sets: 3, reps: "20 reps", equipment: .barra, muscle: "Antebraço extensor", symbol: "dumbbell.fill", instructions: ["Pegada pronada, antebraços nos joelhos.", "Eleve os punhos para cima."]),
    Exercise(name: "Farmer hold (isometria de pegada)", sets: 3, reps: "30 s", equipment: .halteres, muscle: "Pegada e antebraço", symbol: "figure.walk", instructions: ["Segure halteres pesados ao lado do corpo.", "Aguente o tempo sem soltar."]),
    Exercise(name: "Plate pinch (pinça com anilha)", sets: 3, reps: "30 s", equipment: .anilha, muscle: "Pegada", symbol: "circle.circle.fill", instructions: ["Segure uma anilha com polegar e dedos.", "Mantenha sem soltar pelo tempo determinado."]),
    Exercise(name: "Bar hang (suspensão na barra)", sets: 3, reps: "30 s", equipment: .corporal, muscle: "Pegada e ombros", symbol: "figure.strengthtraining.functional", instructions: ["Pendurado na barra com os braços estendidos.", "Relaxe os ombros e respire."]),
    Exercise(name: "Dead hang ativo", sets: 3, reps: "20 s", equipment: .corporal, muscle: "Pegada e escápulas", symbol: "figure.strengthtraining.functional", instructions: ["Pendurado na barra, ative as escápulas.", "Afaste levemente os ombros das orelhas."]),
    Exercise(name: "Towel pull-up", sets: 3, reps: "6 reps", equipment: .corporal, muscle: "Pegada e costas", symbol: "figure.strengthtraining.functional", instructions: ["Coloque uma toalha sobre a barra e segure as duas pontas.", "Faça a barra fixa com as toalhas."]),
    Exercise(name: "Rosca de punho com halter (pronado)", sets: 3, reps: "15 reps", equipment: .halteres, muscle: "Antebraço", symbol: "dumbbell.fill", instructions: ["Antebraço apoiado no joelho, punho neutro.", "Flex ione e estenda o punho."]),
    Exercise(name: "Rice bucket (balde de arroz)", sets: 2, reps: "3 min", equipment: .corporal, muscle: "Antebraço e dedos", symbol: "dumbbell.fill", instructions: ["Mergulhe a mão num balde de arroz.", "Abra, feche e gire a mão por 3 minutos."]),
    Exercise(name: "Squeeze de bola (isometria)", sets: 3, reps: "30 s cada", equipment: .corporal, muscle: "Pegada", symbol: "circle.fill", instructions: ["Segure uma bola de tênis ou de stress.", "Aperte o máximo possível e mantenha."]),

    // MARK: Pernas — adicional (12)
    Exercise(name: "Agachamento no TRX", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Pernas e equilíbrio", symbol: "figure.cross.training", instructions: ["Segure as alças do TRX para apoio.", "Agache em amplitude total usando o TRX para balancear."]),
    Exercise(name: "Avanço com salto (plyometric lunge)", sets: 4, reps: "10 cada", equipment: .corporal, muscle: "Pernas e glúteos", symbol: "figure.highintensity.intervaltraining", instructions: ["Na posição de avanço, salte trocando as pernas.", "Aterrisse suave amortecendo os joelhos."]),
    Exercise(name: "Leg press com pés baixos", sets: 3, reps: "12 reps", equipment: .maquina, muscle: "Quadríceps — foco", symbol: "gearshape.2.fill", instructions: ["Pés próximos à borda inferior da plataforma.", "Amplitude maior nos joelhos."]),
    Exercise(name: "Leg press com pés altos", sets: 3, reps: "12 reps", equipment: .maquina, muscle: "Glúteos e isquiotibiais", symbol: "gearshape.2.fill", instructions: ["Pés próximos à borda superior da plataforma.", "Enfatiza glúteos e posterior."]),
    Exercise(name: "Cadeira extensora unilateral", sets: 3, reps: "12 cada", equipment: .maquina, muscle: "Quadríceps unilateral", symbol: "gearshape.2.fill", instructions: ["Uma perna por vez.", "Estenda completamente e controle a descida."]),
    Exercise(name: "Mesa flexora unilateral", sets: 3, reps: "12 cada", equipment: .maquina, muscle: "Isquiotibiais unilateral", symbol: "gearshape.2.fill", instructions: ["Uma perna por vez.", "Flexione e controle a descida."]),
    Exercise(name: "Passada com kettlebell", sets: 3, reps: "12 cada", equipment: .kettlebell, muscle: "Pernas e glúteos", symbol: "figure.cross.training", instructions: ["Kettlebell na posição rack ou ao lado.", "Passo à frente e desça o joelho de trás."]),
    Exercise(name: "Agachamento com pausa", sets: 4, reps: "8 reps", equipment: .barra, muscle: "Pernas — tempo sob tensão", symbol: "figure.strengthtraining.functional", instructions: ["Agache normalmente.", "Pause 3 segundos no ponto mais baixo antes de subir."]),
    Exercise(name: "Nordic curl (isquiotibiais)", sets: 3, reps: "6 reps", equipment: .corporal, muscle: "Isquiotibiais — excêntrico", symbol: "figure.strengthtraining.functional", instructions: ["Joelhos no chão, tornozelos fixos.", "Desça o tronco à frente lentamente resistindo com os isquiotibiais."]),
    Exercise(name: "Sobe e desce no banco", sets: 4, reps: "15 cada", equipment: .banco, muscle: "Pernas e glúteos", symbol: "chair.lounge.fill", instructions: ["Suba no banco com uma perna por vez.", "Alterne a perna de liderança."]),
    Exercise(name: "Agachamento isométrico (wall sit)", sets: 3, reps: "45 s", equipment: .corporal, muscle: "Quadríceps — isometria", symbol: "figure.cross.training", instructions: ["Costas na parede, joelhos a 90 graus.", "Mantenha a posição sem encostar as mãos nas pernas."]),
    Exercise(name: "Panturrilha em leg press", sets: 3, reps: "20 reps", equipment: .maquina, muscle: "Panturrilha", symbol: "gearshape.2.fill", instructions: ["Pés na borda inferior da plataforma.", "Suba na ponta dos pés e desça controlado."]),

    // MARK: Glúteos — adicional (10)
    Exercise(name: "Fire hydrant (hidrante)", sets: 3, reps: "20 cada", equipment: .corporal, muscle: "Glúteo médio", symbol: "figure.core.training", instructions: ["De quatro, mantenha o joelho dobrado.", "Eleve a perna lateralmente como cachorro marcando território."]),
    Exercise(name: "Glute bridge unilateral", sets: 3, reps: "15 cada", equipment: .corporal, muscle: "Glúteos unilateral", symbol: "figure.core.training", instructions: ["Deitado, uma perna estendida.", "Eleve o quadril apenas com a perna apoiada."]),
    Exercise(name: "Donkey kick com pulso", sets: 3, reps: "20 cada", equipment: .corporal, muscle: "Glúteos", symbol: "figure.core.training", instructions: ["De quatro, calcanha sobe ao teto.", "Dê um pulso extra no topo do movimento."]),
    Exercise(name: "Abducão de quadril deitado de lado", sets: 3, reps: "20 cada", equipment: .corporal, muscle: "Glúteo médio e TFL", symbol: "figure.core.training", instructions: ["Deitado de lado, perna de cima estendida.", "Eleve e desça controlando."]),
    Exercise(name: "Hip thrust com barra — pé de sumo", sets: 4, reps: "12 reps", equipment: .barra, muscle: "Glúteos e adutores", symbol: "figure.strengthtraining.functional", instructions: ["Pés afastados, pontas para fora.", "Eleve o quadril contraindo glúteos e adutores."]),
    Exercise(name: "Step up com halteres e joelho elevado", sets: 3, reps: "12 cada", equipment: .halteres, muscle: "Glúteos e equilíbrio", symbol: "chair.lounge.fill", instructions: ["Suba no banco e ao subir eleve o joelho a 90 graus.", "Segure 1s e desça controlado."]),
    Exercise(name: "Frog pump", sets: 3, reps: "25 reps", equipment: .corporal, muscle: "Glúteos", symbol: "figure.core.training", instructions: ["Deitado, plantas dos pés juntas.", "Eleve e desça o quadril em ritmo rápido."]),
    Exercise(name: "Banded glute bridge", sets: 4, reps: "20 reps", equipment: .elastico, muscle: "Glúteos com tensão", symbol: "figure.flexibility", instructions: ["Elástico acima dos joelhos, deitado.", "Eleve o quadril e empurre os joelhos para fora."]),
    Exercise(name: "Quadrupede hip extension isométrica", sets: 3, reps: "30 s cada", equipment: .corporal, muscle: "Glúteo máximo — isometria", symbol: "figure.core.training", instructions: ["De quatro, eleve uma perna estendida.", "Mantenha sem mover o quadril."]),
    Exercise(name: "Afundo lateral com salto", sets: 3, reps: "10 cada", equipment: .corporal, muscle: "Glúteos e adutores", symbol: "figure.highintensity.intervaltraining", instructions: ["Passo lateral profundo e salte ao retornar.", "Aterrisse suave alternando lados."]),

    // MARK: Costas — adicional (8)
    Exercise(name: "Remada T-bar", sets: 4, reps: "10 reps", equipment: .barra, muscle: "Costas — espessura", symbol: "figure.rower", instructions: ["Barra presa num canto, haltere no outro.", "Puxe ao tronco com as duas mãos."]),
    Exercise(name: "Puxada com elástico", sets: 3, reps: "15 reps", equipment: .elastico, muscle: "Costas", symbol: "figure.flexibility", instructions: ["Prenda o elástico acima.", "Puxe para baixo até o peito como na puxada alta."]),
    Exercise(name: "Remada prone no banco", sets: 3, reps: "12 reps", equipment: .halteres, muscle: "Costas — isolado", symbol: "figure.rower", instructions: ["Deite de bruços no banco inclinado.", "Puxe os halteres em remada bilateral."]),
    Exercise(name: "Cable straight arm pulldown", sets: 3, reps: "15 reps", equipment: .cabo, muscle: "Lat — isolado", symbol: "figure.strengthtraining.functional", instructions: ["Polia alta, barra longa.", "Com braços retos, puxe a barra até o quadril."]),
    Exercise(name: "Single arm cable pulldown", sets: 3, reps: "12 cada", equipment: .cabo, muscle: "Lat unilateral", symbol: "figure.strengthtraining.functional", instructions: ["Polia alta, puxador de alça.", "Puxe com um braço só ao quadril."]),
    Exercise(name: "Remada inclinada com anilha", sets: 3, reps: "12 cada", equipment: .anilha, muscle: "Costas e braço", symbol: "figure.rower", instructions: ["Tronco inclinado, segure a anilha.", "Puxe ao tronco contraindo as costas."]),
    Exercise(name: "Deficit pull-up", sets: 3, reps: "max reps", equipment: .corporal, muscle: "Costas — amplitude", symbol: "figure.strengthtraining.functional", instructions: ["Barra fixa com pegada larga.", "Desça até os braços totalmente estendidos."]),
    Exercise(name: "Inverted row (remada australiana)", sets: 3, reps: "12 reps", equipment: .corporal, muscle: "Costas — corporal", symbol: "figure.strengthtraining.functional", instructions: ["Deitado sob uma barra baixa.", "Puxe o peito até a barra mantendo o corpo reto."]),

    // MARK: Peito — adicional (8)
    Exercise(name: "Flexão archer (arqueiro)", sets: 3, reps: "8 cada", equipment: .corporal, muscle: "Peito unilateral", symbol: "figure.strengthtraining.traditional", instructions: ["Posição de flexão, braço direito estendido.", "Flexione o lado esquerdo descendo ao chão."]),
    Exercise(name: "Flexão hindu", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Peito, ombros e coluna", symbol: "figure.flexibility", instructions: ["Comece com quadril elevado.", "Mergulhe o tronco descrevendo um arco até a cobra."]),
    Exercise(name: "Flexão wide (larga)", sets: 3, reps: "15 reps", equipment: .corporal, muscle: "Peito externo", symbol: "figure.strengthtraining.traditional", instructions: ["Mãos bem afastadas, foco no peito externo.", "Desça com cotovelos abertos."]),
    Exercise(name: "Cable crossover baixo (polia baixa)", sets: 3, reps: "12 reps", equipment: .cabo, muscle: "Peito superior", symbol: "figure.strengthtraining.functional", instructions: ["Polias baixas, cruze os braços subindo.", "Enfatiza a porção clavicular."]),
    Exercise(name: "Supino com anilha (grip diferente)", sets: 3, reps: "10 reps", equipment: .anilha, muscle: "Peito e estabilizadores", symbol: "circle.circle.fill", instructions: ["Segure anilhas verticalmente.", "Realize o supino com foco em estabilizar."]),
    Exercise(name: "Bench dip com peso", sets: 3, reps: "12 reps", equipment: .banco, muscle: "Tríceps e peito inferior", symbol: "chair.lounge.fill", instructions: ["Mãos no banco, anilha no colo.", "Desça e suba com o peso extra."]),
    Exercise(name: "Flexão com pés elevados (pike)", sets: 3, reps: "10 reps", equipment: .corporal, muscle: "Peito superior e ombros", symbol: "figure.strengthtraining.traditional", instructions: ["Quadril elevado, pés no chão.", "Desça a cabeça ao chão."]),
    Exercise(name: "Supino com barra hex (trap bar)", sets: 4, reps: "10 reps", equipment: .barra, muscle: "Peito — variação de pegada", symbol: "figure.strengthtraining.traditional", instructions: ["Pegada neutra com barra hex.", "Realize o supino com amplitude total."]),

    // MARK: Ombros — adicional (8)
    Exercise(name: "Lateral raise machine", sets: 3, reps: "15 reps", equipment: .maquina, muscle: "Deltoide lateral", symbol: "gearshape.2.fill", instructions: ["Ajuste a máquina na altura dos cotovelos.", "Pressione os suportes para cima."]),
    Exercise(name: "Kettlebell press unilateral", sets: 3, reps: "10 cada", equipment: .kettlebell, muscle: "Ombros e core", symbol: "dumbbell.fill", instructions: ["Kettlebell em posição rack.", "Pressione acima da cabeça estabilizando o core."]),
    Exercise(name: "Push press unilateral (halter)", sets: 3, reps: "10 cada", equipment: .halteres, muscle: "Ombros — potência", symbol: "dumbbell.fill", instructions: ["Halter no ombro, semiflexão de joelhos.", "Use o impulso das pernas para empurrar o halter."]),
    Exercise(name: "Bent-over lateral raise", sets: 3, reps: "15 reps", equipment: .halteres, muscle: "Deltoide posterior", symbol: "dumbbell.fill", instructions: ["Tronco inclinado a 90 graus.", "Eleve os braços lateralmente contraindo o deltoide posterior."]),
    Exercise(name: "Cable front raise", sets: 3, reps: "12 reps", equipment: .cabo, muscle: "Deltoide anterior", symbol: "figure.strengthtraining.functional", instructions: ["Polia baixa, barra ou alça.", "Eleve o braço até a altura dos ombros."]),
    Exercise(name: "Lateral raise 21s", sets: 3, reps: "21 reps", equipment: .halteres, muscle: "Deltoide lateral", symbol: "dumbbell.fill", instructions: ["7 meia amplitude inferior, 7 meia superior, 7 completos.", "Sem pausa entre as fases."]),
    Exercise(name: "Overhead press (landmine)", sets: 3, reps: "10 cada", equipment: .barra, muscle: "Ombros e core", symbol: "figure.strengthtraining.functional", instructions: ["Barra em landmine, um braço de cada vez.", "Pressione diagonalmente acima da cabeça."]),
    Exercise(name: "Rotação de manguito com haltere", sets: 3, reps: "15 cada", equipment: .halteres, muscle: "Manguito rotador", symbol: "dumbbell.fill", instructions: ["Deitado de lado, cotovelo a 90 graus.", "Gire o antebraço para cima e para baixo controlando."]),

    // MARK: Banco (8)
    Exercise(name: "Hip thrust no banco com peso corporal", sets: 3, reps: "20 reps", equipment: .banco, muscle: "Glúteos", symbol: "chair.lounge.fill", instructions: ["Ombros no banco, apenas peso corporal.", "Eleve o quadril em amplitude total."]),
    Exercise(name: "Decline push-up no banco", sets: 3, reps: "12 reps", equipment: .banco, muscle: "Peito superior e ombros", symbol: "chair.lounge.fill", instructions: ["Pés no banco, mãos no chão.", "Flexão com ênfase no peito superior."]),
    Exercise(name: "Bulgarian split squat com banco", sets: 3, reps: "10 cada", equipment: .banco, muscle: "Quadríceps e glúteos", symbol: "chair.lounge.fill", instructions: ["Pé traseiro apoiado no banco.", "Desça o joelho de trás ao chão."]),
    Exercise(name: "Chest supported row (remada no banco)", sets: 4, reps: "12 reps", equipment: .banco, muscle: "Costas", symbol: "chair.lounge.fill", instructions: ["Apoie o peito no banco inclinado.", "Puxe os halteres até os lados do tronco."]),
    Exercise(name: "Incline curl (rosca inclinada)", sets: 3, reps: "12 reps", equipment: .banco, muscle: "Bíceps — cabeça longa", symbol: "chair.lounge.fill", instructions: ["Sentado no banco inclinado, braços pendendo.", "Rosca completa mantendo os cotovelos atrás do tronco."]),
    Exercise(name: "Seated incline lateral raise", sets: 3, reps: "15 reps", equipment: .banco, muscle: "Deltoide lateral", symbol: "chair.lounge.fill", instructions: ["Sentado no banco inclinado de lado.", "Eleve o braço de baixo até acima da cabeça."]),
    Exercise(name: "Box dip (paralela no banco)", sets: 4, reps: "15 reps", equipment: .banco, muscle: "Tríceps", symbol: "chair.lounge.fill", instructions: ["Mãos no banco atrás, pés no chão.", "Desça dobrando os cotovelos a 90 graus."]),
    Exercise(name: "Single leg hip thrust no banco", sets: 3, reps: "12 cada", equipment: .banco, muscle: "Glúteos unilateral", symbol: "chair.lounge.fill", instructions: ["Ombros no banco, uma perna estendida.", "Eleve o quadril com a perna apoiada."]),

    // MARK: Anilha (8)
    Exercise(name: "Around the world com anilha", sets: 3, reps: "10 reps", equipment: .anilha, muscle: "Ombros e core", symbol: "circle.circle.fill", instructions: ["Em pé, segure a anilha à frente.", "Faça um círculo ao redor da cabeça alternando direções."]),
    Exercise(name: "Hack squat com anilha", sets: 3, reps: "12 reps", equipment: .anilha, muscle: "Pernas", symbol: "circle.circle.fill", instructions: ["Segure a anilha atrás das pernas.", "Agache e suba estendendo os joelhos."]),
    Exercise(name: "Plank com anilha nas costas", sets: 3, reps: "30 s", equipment: .anilha, muscle: "Core — sobrecarregado", symbol: "circle.circle.fill", instructions: ["Peça a um parceiro que coloque a anilha nas costas.", "Mantenha a prancha com a carga extra."]),
    Exercise(name: "Swing com anilha", sets: 4, reps: "15 reps", equipment: .anilha, muscle: "Posterior e core", symbol: "circle.circle.fill", instructions: ["Segure a anilha com as duas mãos.", "Realize o swing como no kettlebell."]),
    Exercise(name: "Landmine rotação com anilha", sets: 3, reps: "10 cada", equipment: .anilha, muscle: "Oblíquos e core", symbol: "circle.circle.fill", instructions: ["Barra em landmine, segure com as duas mãos.", "Gire o tronco levando a barra de um lado ao outro."]),
    Exercise(name: "Agachamento com anilha overhead", sets: 3, reps: "10 reps", equipment: .anilha, muscle: "Pernas, core e ombros", symbol: "circle.circle.fill", instructions: ["Segure a anilha com braços estendidos acima.", "Agache mantendo a anilha alinhada."]),
    Exercise(name: "Halo com anilha", sets: 3, reps: "10 cada", equipment: .anilha, muscle: "Ombros e core", symbol: "circle.circle.fill", instructions: ["Em pé, anilha verticalmente à frente.", "Faça círculos ao redor da cabeça controlado."]),
    Exercise(name: "Deadlift com anilha (unilateral)", sets: 3, reps: "10 cada", equipment: .anilha, muscle: "Posterior unilateral", symbol: "circle.circle.fill", instructions: ["Segure a anilha com uma mão.", "Levantamento terra unilateral focando equilíbrio."])
]

// MARK: - Ponte com o app Alma (App Group compartilhado)

/// Compartilha estado entre Corpo & Alma e Alma via App Group `group.com.almaapp.shared`.
/// O Alma escreve `alma_active`/assinatura; aqui lemos e também publicamos o premium.
struct AlmaBridge {
    static let shared = AlmaBridge()
    private let suite = UserDefaults(suiteName: "group.com.almaapp.shared")
    private let freshness: TimeInterval = 60 * 60 * 24 * 30   // 30 dias

    /// True se o app Alma assinante gravou presença recente no grupo compartilhado.
    var almaConnected: Bool { almaHasPremium || (suite?.bool(forKey: "alma_active") ?? false) }

    /// O usuário tem assinatura ativa no app Alma? (flag gravado pelo Alma)
    var almaHasPremium: Bool {
        guard let d = suite,
              let updated = d.object(forKey: "alma_isPremium_updatedAt") as? Date,
              Date().timeIntervalSince(updated) < freshness else { return false }
        return d.bool(forKey: "alma_isPremium")
    }

    var sharedUserName: String? { suite?.string(forKey: "shared_user_name") }

    /// Publica o premium deste app (Corpo & Alma) para o Alma ler.
    func setPremium(_ value: Bool) {
        suite?.set(value, forKey: "corpoealma_isPremium")
        suite?.set(Date(), forKey: "corpoealma_isPremium_updatedAt")
    }
    func setUserName(_ name: String) { suite?.set(name, forKey: "shared_user_name") }

    /// Abre o app Alma se instalado; senão, a página do Alma na App Store.
    /// CTA da assinatura única: quem assina no Corpo & Alma também usa o Alma. [2026-07-18]
    static func openAlmaApp() {
        let schemeURL = URL(string: "alma://")!
        let storeURL  = URL(string: "https://apps.apple.com/app/id6761478534")!
        if UIApplication.shared.canOpenURL(schemeURL) {
            UIApplication.shared.open(schemeURL)
        } else {
            UIApplication.shared.open(storeURL)
        }
    }
}
