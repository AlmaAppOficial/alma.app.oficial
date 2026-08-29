// AlmaJejumWidgetBundle.swift
// Alma — a extensão que desenha o cronômetro do jejum na tela bloqueada.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE EXISTE UM ALVO NOVO SÓ PARA ISTO
//
// No iOS, contador correndo na tela bloqueada só existe por Live Activity, e
// Live Activity só é desenhada por uma extensão de widget — a interface roda no
// processo do `.appex`, nunca no do app. Não há caminho mais barato: notificação
// comum no iOS não tem contador vivo (não existe equivalente do
// `setUsesChronometer` do Android), e widget de tela de início não aparece na
// tela bloqueada.
//
// O projeto já tinha UMA extensão, a `AlmaComplicationExtension`, mas ela é
// watchOS (`SDKROOT = watchos`) e vive dentro do app do relógio. Não dava para
// aproveitar: a atividade ao vivo precisa estar embarcada no app iOS.
//
// ═══════════════════════════════════════════════════════════════════════════
// O BUNDLE SÓ TEM A ATIVIDADE — NÃO HÁ WIDGET DE TELA DE INÍCIO
//
// De propósito. O pedido é o cronômetro na tela bloqueada. Um widget de tela de
// início do jejum seria outra funcionalidade, com outras decisões (o que mostrar
// quando não há jejum? some ou fica vazio?), e entrar de carona aqui seria
// escopo que ninguém pediu. O `WidgetBundle` aceita ser acrescentado depois sem
// mexer em nada disto.

import WidgetKit
import SwiftUI

@main
struct AlmaJejumWidgetBundle: WidgetBundle {
    var body: some Widget {
        JejumAoVivoWidget()
    }
}
