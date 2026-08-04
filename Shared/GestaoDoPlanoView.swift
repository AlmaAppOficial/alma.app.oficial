// GestaoDoPlanoView.swift
// Alma — o que o ASSINANTE vê quando toca em "meu plano"
//
// [2026-08-04 — bug relatado pelo Assis: "eu sou Premium e o app continua me
// oferecendo o Premium"]
//
// O app tinha uma porta só. Tanto o Perfil do Alma (`ProfileView.premiumRow`)
// quanto os Ajustes do Corpo (`Corpo/SettingsView`, linha "Gerenciar plano")
// abriam o `PremiumWallView` — a tela de VENDA. Quem já pagava via, de novo, a
// lista de benefícios que já tem e um botão "Assinar Alma Premium · R$ …".
//
// Isso é ruim em três camadas, da menos para a mais grave:
//   1. é inútil — não há nada a comprar;
//   2. é constrangedor — a pessoa paga e o app age como se não soubesse;
//   3. é arriscado — um CTA de compra ativo para quem já assinou convida a uma
//      segunda cobrança e a Apple trata isso como problema de 3.1.2.
//
// Esta tela é a outra porta. Ela responde três perguntas, nessa ordem:
//   • você tem acesso? (sim/não, sem rodeio)
//   • de onde ele vem? (`OrigemDoAcesso` — e a resposta muda o que faz sentido)
//   • o que dá para fazer com ele agora?
//
// A única ação de gestão real é a folha NATIVA da Apple
// (`AppStore.showManageSubscriptions(in:)`). Não existe tela nossa de
// cancelamento — cancelar assinatura da App Store é da Apple, e qualquer
// imitação nossa seria uma promessa que não podemos cumprir. Por isso o botão
// só aparece para quem de fato tem assinatura na Apple (`temAssinaturaNaApple`):
// para quem tem o acesso herdado do Corpo & Alma, essa folha abriria vazia.

import SwiftUI
import StoreKit

struct GestaoDoPlanoView: View {

    @EnvironmentObject var access: AccessManager
    @EnvironmentObject var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var restaurando = false
    @State private var recado: String?
    @State private var erroAoAbrirApple = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    cabecalho
                    origemCard
                    acoes
                    rodape
                }
                .padding(20)
            }
            .background(CalmTheme.background.ignoresSafeArea())
            .navigationTitle("Seu plano")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") { dismiss() }
                }
            }
        }
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("Alma Premium ativo")
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
            }
            Text("Você tem acesso a tudo que o Premium libera. Nada a comprar aqui.")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
        }
    }

    // MARK: - Origem

    private var origemCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(access.origem.rotulo)
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)
            Text(access.origem.explicacao)
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CalmTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Ações

    @ViewBuilder
    private var acoes: some View {
        VStack(spacing: 12) {
            if access.origem.temAssinaturaNaApple {
                Button {
                    Task { await abrirGestaoDaApple() }
                } label: {
                    Label("Gerenciar assinatura na Apple", systemImage: "arrow.up.forward.app.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(CalmTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if erroAoAbrirApple {
                    // Sem inventar caminho: o texto abaixo é o percurso real na
                    // interface do iOS, para quando a folha nativa não abre.
                    Text("Não consegui abrir a folha da Apple. Você também chega lá por: "
                         + "Ajustes do iPhone → seu nome → Assinaturas.")
                        .font(.footnote)
                        .foregroundColor(CalmTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                Task { await restaurar() }
            } label: {
                HStack(spacing: 8) {
                    if restaurando {
                        ProgressView().scaleEffect(0.8)
                    }
                    Label("Restaurar compras", systemImage: "arrow.clockwise")
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(CalmTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(restaurando)

            if let recado {
                Text(recado)
                    .font(.footnote)
                    .foregroundColor(CalmTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rodape: some View {
        // Nenhuma promessa de valor, período ou trial: o que a pessoa paga está
        // na conta Apple dela, e é de lá que ela deve ler. O app não repete
        // número que não controla.
        Text("O valor e a data da próxima cobrança ficam na sua conta Apple — é a fonte oficial.")
            .font(.footnote)
            .foregroundColor(CalmTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Comportamento

    private func abrirGestaoDaApple() async {
        erroAoAbrirApple = false
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            erroAoAbrirApple = true
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            erroAoAbrirApple = true
        }
    }

    private func restaurar() async {
        restaurando = true
        recado = nil
        let restaurou = await store.restorePurchases()
        await access.refresh()
        restaurando = false
        recado = restaurou
            ? "Compra encontrada e revalidada."
            : "Nenhuma compra nova encontrada. Seu acesso continua ativo."
    }
}

#Preview {
    GestaoDoPlanoView()
        .environmentObject(AccessManager())
        .environmentObject(StoreKitManager())
}
