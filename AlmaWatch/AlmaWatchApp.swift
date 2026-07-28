// AlmaWatchApp.swift
// Alma — app companheiro para Apple Watch (watchOS).
//
// Ponto de entrada. Toda a UI vive em AlmaWatchContentView.swift (vários tipos no
// mesmo arquivo, de propósito: os dois arquivos já estão referenciados no target
// "Alma Watch App" do projeto, então evitamos mexer no project.pbxproj para a parte
// de código).

import SwiftUI

@main
struct AlmaWatchApp: App {
    var body: some Scene {
        WindowGroup {
            AlmaWatchContentView()
        }
    }
}
