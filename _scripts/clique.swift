// clique.swift — eventos de mouse/rolagem para automatizar o Simulator.
// Compilar: swiftc -O -o /tmp/clique clique.swift
// Uso:
//   clique click X Y            — clique simples
//   clique hold X Y MS          — pressiona, segura MS milissegundos, solta (long press)
//   clique scroll X Y DY [N]    — N rolagens de DY (negativo = para baixo) na posição
//   clique move X Y             — só move o cursor
import Foundation
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 4, let x = Double(args[2]), let y = Double(args[3]) else {
    print("uso: clique click|hold|scroll|move X Y [extra]")
    exit(64)
}
let ponto = CGPoint(x: x, y: y)
let fonte = CGEventSource(stateID: .hidSystemState)

func post(_ e: CGEvent?) { e?.post(tap: .cghidEventTap) }

func mover() {
    post(CGEvent(mouseEventSource: fonte, mouseType: .mouseMoved,
                 mouseCursorPosition: ponto, mouseButton: .left))
    usleep(120_000)
}

switch args[1] {
case "move":
    mover()
case "click":
    mover()
    post(CGEvent(mouseEventSource: fonte, mouseType: .leftMouseDown,
                 mouseCursorPosition: ponto, mouseButton: .left))
    usleep(80_000)
    post(CGEvent(mouseEventSource: fonte, mouseType: .leftMouseUp,
                 mouseCursorPosition: ponto, mouseButton: .left))
case "hold":
    let ms = args.count > 4 ? (Int(args[4]) ?? 900) : 900
    mover()
    post(CGEvent(mouseEventSource: fonte, mouseType: .leftMouseDown,
                 mouseCursorPosition: ponto, mouseButton: .left))
    usleep(UInt32(ms) * 1000)
    post(CGEvent(mouseEventSource: fonte, mouseType: .leftMouseUp,
                 mouseCursorPosition: ponto, mouseButton: .left))
case "scroll":
    let dy = args.count > 4 ? (Int32(args[4]) ?? -3) : -3
    let n = args.count > 5 ? (Int(args[5]) ?? 1) : 1
    mover()
    for _ in 0..<n {
        post(CGEvent(scrollWheelEvent2Source: fonte, units: .line,
                     wheelCount: 1, wheel1: dy, wheel2: 0, wheel3: 0))
        usleep(90_000)
    }
default:
    print("ação desconhecida: \(args[1])")
    exit(64)
}
usleep(150_000)
