import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Interactive prompts. Every function returns nil when the user backs out
/// (esc in a terminal, "<" on text / "0" on menus in plain pipes) and
/// `canGoBack` is set.
enum Prompt {
    static var interactive: Bool {
        isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
            && ProcessInfo.processInfo.environment["TERM"] != "dumb"
    }

    static let cyan = "\u{1B}[36m", green = "\u{1B}[32m", dim = "\u{1B}[2m", reset = "\u{1B}[0m"

    static func text(_ label: String, defaultValue: String? = nil, canGoBack: Bool = false) -> String? {
        while true {
            let hints = [defaultValue.map { "(\($0))" }, backHint(canGoBack)]
                .compactMap { $0 }.joined(separator: " ")
            let prompt = "\(green)?\(reset) \(label)\(hints.isEmpty ? "" : " \(dim)\(hints)\(reset)") \(cyan)›\(reset) "
            let answer: String
            if interactive {
                switch editLine(prompt: prompt) {
                case .back:
                    if canGoBack { return nil }
                    continue
                case .entered(let line):
                    answer = line.trimmingCharacters(in: .whitespaces)
                }
            } else {
                emit(prompt)
                answer = (readLine() ?? "").trimmingCharacters(in: .whitespaces)
                if canGoBack && answer == "<" { return nil }
            }
            if !answer.isEmpty { return answer }
            if let defaultValue { return defaultValue }
        }
    }

    static func confirm(_ label: String, defaultValue: Bool = true, canGoBack: Bool = false) -> Bool? {
        let keys = defaultValue ? "[Y/n]" : "[y/N]"
        let hints = [keys, backHint(canGoBack)].compactMap { $0 }.joined(separator: " ")
        let prompt = "\(green)?\(reset) \(label) \(dim)\(hints)\(reset) "
        guard interactive, let raw = RawMode() else {
            emit(prompt)
            let answer = (readLine() ?? "").trimmingCharacters(in: .whitespaces).lowercased()
            if canGoBack && answer == "<" { return nil }
            if answer.isEmpty { return defaultValue }
            return answer.hasPrefix("y")
        }
        defer { raw.restore() }
        emit(prompt)
        while true {
            switch readKey() {
            case .character("y"), .character("Y"): emit("y\n"); return true
            case .character("n"), .character("N"): emit("n\n"); return false
            case .enter: emit((defaultValue ? "y" : "n") + "\n"); return defaultValue
            case .escape where canGoBack: emit("\n"); return nil
            case .ctrlC: raw.restore(); emit("\n"); exit(130)
            default: break
            }
        }
    }

    static func select(_ label: String, options: [String], initial: Int = 0,
                       canGoBack: Bool = false) -> Int? {
        precondition(!options.isEmpty)
        guard options.count > 1 else { return 0 }
        guard interactive, let raw = RawMode() else {
            return numberedSelect(label, options: options, canGoBack: canGoBack)
        }
        defer { raw.restore() }

        let hints = ["↑↓ + enter", canGoBack ? "esc = back" : nil].compactMap { $0 }.joined(separator: ", ")
        print("\(green)?\(reset) \(label) \(dim)(\(hints))\(reset)")
        var selected = min(max(initial, 0), options.count - 1)
        emit("\u{1B}[?25l")
        defer { emit("\u{1B}[?25h") }
        var drawn = false
        while true {
            if drawn { emit("\u{1B}[\(options.count)A") }
            for (index, option) in options.enumerated() {
                emit("\u{1B}[2K\r")
                print(index == selected ? "\(cyan)❯ \(option)\(reset)" : "  \(option)")
            }
            drawn = true
            switch readKey() {
            case .up: selected = (selected + options.count - 1) % options.count
            case .down: selected = (selected + 1) % options.count
            case .enter: return selected
            case .escape where canGoBack: return nil
            case .ctrlC: raw.restore(); emit("\u{1B}[?25h\n"); exit(130)
            default: break
            }
        }
    }

    static func multiSelect(_ label: String, options: [String], preselected: Set<Int> = [],
                            canGoBack: Bool = false) -> Set<Int>? {
        precondition(!options.isEmpty)
        guard interactive, let raw = RawMode() else {
            return numberedMultiSelect(label, options: options, preselected: preselected,
                                       canGoBack: canGoBack)
        }
        defer { raw.restore() }

        let hints = ["space toggles, enter confirms", canGoBack ? "esc = back" : nil]
            .compactMap { $0 }.joined(separator: ", ")
        print("\(green)?\(reset) \(label) \(dim)(\(hints))\(reset)")
        var selected = preselected.isEmpty ? Set(options.indices) : preselected
        var cursor = 0
        emit("\u{1B}[?25l")
        defer { emit("\u{1B}[?25h") }
        var drawn = false
        while true {
            if drawn { emit("\u{1B}[\(options.count)A") }
            for (index, option) in options.enumerated() {
                emit("\u{1B}[2K\r")
                let mark = selected.contains(index) ? "\(green)◉\(reset)" : "◯"
                let line = "\(mark) \(option)"
                print(index == cursor ? "\(cyan)❯\(reset) \(line)" : "  \(line)")
            }
            drawn = true
            switch readKey() {
            case .up: cursor = (cursor + options.count - 1) % options.count
            case .down: cursor = (cursor + 1) % options.count
            case .space:
                if selected.contains(cursor) { selected.remove(cursor) } else { selected.insert(cursor) }
            case .enter:
                if !selected.isEmpty { return selected }
            case .escape where canGoBack: return nil
            case .ctrlC: raw.restore(); emit("\u{1B}[?25h\n"); exit(130)
            default: break
            }
        }
    }

    // MARK: raw-mode line editor

    private enum LineResult {
        case entered(String)
        case back
    }

    private static func editLine(prompt: String) -> LineResult {
        guard let raw = RawMode() else {
            emit(prompt)
            return .entered(readLine() ?? "")
        }
        defer { raw.restore() }
        emit(prompt)
        var composed = ""
        var pending: [UInt8] = []
        while true {
            var byte: UInt8 = 0
            guard read(STDIN_FILENO, &byte, 1) == 1 else { continue }
            switch byte {
            case 3:
                raw.restore(); emit("\n"); exit(130)
            case 10, 13:
                emit("\n")
                return .entered(composed)
            case 127, 8:
                pending.removeAll()
                if !composed.isEmpty {
                    composed.removeLast()
                    emit("\r\u{1B}[2K" + prompt + composed)
                }
            case 27:
                if consumeEscapeSequence() { break }
                emit("\n")
                return .back
            default:
                guard byte >= 32 || byte == 9 else { break }
                pending.append(byte)
                if let fragment = String(bytes: pending, encoding: .utf8) {
                    composed += fragment
                    emit(fragment)
                    pending.removeAll()
                }
            }
        }
    }

    // MARK: fallbacks for pipes / dumb terminals

    private static func numberedSelect(_ label: String, options: [String], canGoBack: Bool) -> Int? {
        print("? \(label)")
        for (index, option) in options.enumerated() { print("  \(index + 1)) \(option)") }
        if canGoBack { print("  0) ← back") }
        while true {
            emit("Enter a number (\(canGoBack ? "0" : "1")-\(options.count)) › ")
            guard let answer = readLine(),
                  let number = Int(answer.trimmingCharacters(in: .whitespaces)) else { continue }
            if canGoBack && number == 0 { return nil }
            if (1...options.count).contains(number) { return number - 1 }
        }
    }

    private static func numberedMultiSelect(_ label: String, options: [String],
                                            preselected: Set<Int>, canGoBack: Bool) -> Set<Int>? {
        print("? \(label)")
        for (index, option) in options.enumerated() { print("  \(index + 1)) \(option)") }
        emit("Enter numbers separated by commas (empty = all\(canGoBack ? ", 0 = back" : "")) › ")
        let numbers = (readLine() ?? "").split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if canGoBack && numbers == [0] { return nil }
        let valid = numbers.filter { (1...options.count).contains($0) }
        return valid.isEmpty ? Set(options.indices) : Set(valid.map { $0 - 1 })
    }

    private static func backHint(_ canGoBack: Bool) -> String? {
        guard canGoBack else { return nil }
        return interactive ? "(esc = back)" : "(< = back)"
    }

    private static func emit(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    // MARK: key decoding

    private enum Key {
        case up, down, enter, space, escape, ctrlC, character(Character), other
    }

    private static func readKey() -> Key {
        var byte: UInt8 = 0
        guard read(STDIN_FILENO, &byte, 1) == 1 else { return .other }
        switch byte {
        case 3: return .ctrlC
        case 10, 13: return .enter
        case 32: return .space
        case 27:
            var tail = [UInt8](repeating: 0, count: 2)
            let count = readWithTimeout(&tail)
            if count == 0 { return .escape }
            if count >= 2 && tail[0] == 91 {
                if tail[1] == 65 { return .up }
                if tail[1] == 66 { return .down }
            }
            return .other
        case 33...126: return .character(Character(UnicodeScalar(byte)))
        default: return .other
        }
    }

    /// Distinguishes a bare esc keypress from an escape sequence (arrows etc.).
    private static func consumeEscapeSequence() -> Bool {
        var tail = [UInt8](repeating: 0, count: 2)
        return readWithTimeout(&tail) > 0
    }

    private static func readWithTimeout(_ buffer: inout [UInt8]) -> Int {
        var settings = termios()
        tcgetattr(STDIN_FILENO, &settings)
        let saved = settings
        withUnsafeMutableBytes(of: &settings.c_cc) {
            $0[Int(VMIN)] = 0
            $0[Int(VTIME)] = 1
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &settings)
        let count = buffer.withUnsafeMutableBytes { read(STDIN_FILENO, $0.baseAddress, $0.count) }
        var restore = saved
        tcsetattr(STDIN_FILENO, TCSANOW, &restore)
        return max(count, 0)
    }

    private struct RawMode {
        private var original = termios()

        init?() {
            guard tcgetattr(STDIN_FILENO, &original) == 0 else { return nil }
            var raw = original
            raw.c_lflag &= ~tcflag_t(ECHO | ICANON)
            withUnsafeMutableBytes(of: &raw.c_cc) {
                $0[Int(VMIN)] = 1
                $0[Int(VTIME)] = 0
            }
            guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { return nil }
        }

        func restore() {
            var settings = original
            tcsetattr(STDIN_FILENO, TCSANOW, &settings)
        }
    }
}
