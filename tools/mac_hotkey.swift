// Optional, macOS only. Carbon hotkeys require no Accessibility keyboard monitoring.
// Compile with tools/start_hotkey.command; no third-party libraries or login credentials.
import Foundation
import Carbon

struct Pairing: Decodable { let port: Int; let key: String }
let arguments = CommandLine.arguments
let useAlternate = arguments.contains("--alternate")
guard let configIndex = arguments.firstIndex(of: "--config"), arguments.count > configIndex + 1 else {
    fputs("Pass --config /absolute/path/to/.local/bridge.json [--alternate]\n", stderr)
    exit(1)
}
let configURL = URL(fileURLWithPath: arguments[configIndex + 1])

func toggleVoice() {
    do {
        // Re-read so bridge restarts / re-pairing recover without restarting this helper.
        let pairing = try JSONDecoder().decode(Pairing.self, from: Data(contentsOf: configURL))
        guard (1024...65535).contains(pairing.port), pairing.key.count == 64,
              let url = URL(string: "http://127.0.0.1:\(pairing.port)/v1/command") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(pairing.key, forHTTPHeaderField: "X-Aisora-Key")
        request.httpBody = Data(#"{"action":"toggle"}"#.utf8)
        URLSession.shared.dataTask(with: request) { _, response, error in
            if error != nil || (response as? HTTPURLResponse)?.statusCode != 200 {
                fputs("Aisora: Voice command unavailable; check the browser/bridge.\n", stderr)
            }
        }.resume()
    } catch {
        fputs("Aisora: start the bridge first so its pairing file exists.\n", stderr)
    }
}

let signature: OSType = 0x4149534F // AISO
var handler: EventHandlerRef?
var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
    guard let event = event else { return OSStatus(eventNotHandledErr) }
    var hotkey = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hotkey)
    if status == noErr && hotkey.signature == 0x4149534F { toggleVoice(); return noErr }
    return OSStatus(eventNotHandledErr)
}, 1, &eventType, nil, &handler)
var hotkeyRef: EventHotKeyRef?
let keyCode = UInt32(useAlternate ? kVK_ANSI_8 : kVK_F8)
let modifiers = UInt32(useAlternate ? (cmdKey | shiftKey) : 0)
let status = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: signature, id: 1),
                                 GetApplicationEventTarget(), 0, &hotkeyRef)
guard handlerStatus == noErr && status == noErr else {
    fputs("Shortcut unavailable. Try --alternate (Command+Shift+8), or use Godot's F9 option.\n", stderr)
    exit(1)
}
print("Aisora global shortcut: \(useAlternate ? "Command+Shift+8" : "F8"). Keep this Terminal open; Control+C stops it.")
RunApplicationEventLoop()
