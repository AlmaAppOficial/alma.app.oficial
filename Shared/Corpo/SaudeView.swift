//
//  SaudeView.swift
//  Corpo & Alma
//
//  Aba "Saúde" — avaliação do corpo + dados reais do Apple Saúde (HealthKit).
//

import SwiftUI

struct SaudeView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var health: HealthManager
    @State private var editing = false
    @State private var goToScan = false

    @State private var showPaywall = false

    // Peso e IMC preferem o Apple Saúde quando disponível.
    private var currentWeight: Double { health.bodyMass ?? model.weightKg }
    private var currentIMC: Double { currentWeight / pow(model.heightCm / 100, 2) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(title: "Saúde", subtitle: "Sua avaliação corporal de hoje")

                    // Scan corporal: Gemini Vision analisa as fotos + medidas.
                    // Sem API key → MockAIPlanService (plano offline baseado em medidas).
                    scanCard

                    if !health.isAuthorized {
                        connectHealthCard
                    }

                    imcCard

                    SectionTitle(text: "Composição corporal")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        bodyStat("Peso", String(format: "%.1f", currentWeight), "kg", "scalemass.fill", Theme.primary, fromHealth: health.bodyMass != nil)
                        bodyStat("Altura", String(format: "%.0f", model.heightCm), "cm", "ruler.fill", Theme.azure, fromHealth: false)
                        bodyStat("Gordura", String(format: "%.1f", model.bodyFat), "%", "drop.triangle.fill", Theme.coral, fromHealth: false)
                        bodyStat("FC repouso", health.restingHeartRate.map { "\(Int($0))" } ?? "\(model.restingHR)", "bpm", "heart.fill", Theme.violet, fromHealth: health.restingHeartRate != nil)
                    }

                    SectionTitle(text: "Apple Saúde · ao vivo")
                    appleHealthCard
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $editing) { EditAssessmentView() }
            .sheet(isPresented: $showPaywall) { CorpoPaywallView() }
            .navigationDestination(isPresented: $goToScan) { BodyScanView() }

            // Chama requestAuthorization em cada aparição:
            // se já autorizado, HealthKit chama completion sem diálogo e dispara refresh().
            .onAppear { health.requestAuthorization() }
        }
    }

    // Conectar Apple Saúde
    private var connectHealthCard: some View {
        Button { health.requestAuthorization() } label: {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.coral)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conectar Apple Saúde")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("Mostre peso, batimentos, SpO₂ e sono reais do seu iPhone e Apple Watch.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkSoft)
            }
            .cardStyle(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // Card de entrada do Scan corporal com IA
    private var scanCard: some View {
        VStack(spacing: 12) {
            Button {
                if model.hasPremiumAccess { goToScan = true } else { showPaywall = true }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan corporal com IA")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Gere seu plano de dieta e treino sob medida")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: model.hasPremiumAccess ? "chevron.right" : "lock.fill")
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(16)
                .background(LinearGradient(colors: [Theme.primary, Theme.primaryDeep], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
            .buttonStyle(.plain)



            if let saved = model.scanResult {
                NavigationLink {
                    ScanResultView(result: saved)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill").foregroundStyle(Theme.primary)
                        Text("Ver meu plano atual")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                    .cardStyle(padding: 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Card de IMC
    private var imcCard: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: min(currentIMC / 40, 1), tint: Theme.primary, lineWidth: 12)
                    .frame(width: 104, height: 104)
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", currentIMC))
                        .font(.title.bold())
                        .foregroundStyle(Theme.ink)
                    Text("IMC")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(imcClass(currentIMC))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.primary)
                Text("Índice de Massa Corporal calculado a partir do seu peso e altura.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                Pill(text: model.goal.rawValue, tint: model.goal.tint)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private func imcClass(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Abaixo do peso"
        case 18.5..<25: return "Peso saudável"
        case 25..<30: return "Sobrepeso"
        default: return "Obesidade"
        }
    }

    private func bodyStat(_ title: String, _ value: String, _ unit: String, _ icon: String, _ tint: Color, fromHealth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                if fromHealth {
                    Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Theme.coral)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // Dados ao vivo do Apple Saúde
    private var appleHealthCard: some View {
        VStack(spacing: 16) {
            vitalRow("Frequência cardíaca", health.restingHeartRate.map { "\(Int($0)) bpm" }, "waveform.path.ecg", Theme.coral)
            Divider()
            vitalRow("Saturação (SpO₂)", health.oxygen.map { String(format: "%.0f%%", $0) }, "lungs.fill", Theme.azure)
            Divider()
            vitalRow("Variabilidade (HRV)", health.hrv.map { "\(Int($0)) ms" }, "heart.text.square.fill", Theme.primary)
            Divider()
            vitalRow("Passos hoje", health.steps.map { "\(Int($0))" }, "figure.walk", Theme.primary)
            Divider()
            vitalRow("Sono", health.sleepHours.map { String(format: "%.1f h", $0) }, "bed.double.fill", Theme.violet)
        }
        .cardStyle()
    }

    private func vitalRow(_ title: String, _ value: String?, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value ?? "—")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(value == nil ? Theme.inkSoft : Theme.ink)
        }
    }
}

#Preview {
    SaudeView()
        .environmentObject(AppModel())
        .environmentObject(HealthManager())
}
