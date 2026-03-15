import UIKit

/// Simple SC syntax highlighter using NSAttributedString
class SCSyntaxHighlighter {
    static let shared = SCSyntaxHighlighter()

    // Colors matching SC IDE dark theme
    let keywordColor = UIColor.systemPurple
    let classColor = UIColor.systemCyan
    let numberColor = UIColor.systemOrange
    let stringColor = UIColor.systemGreen
    let commentColor = UIColor.systemGray
    let symbolColor = UIColor.systemYellow
    let defaultColor = UIColor.label

    let keywords: Set<String> = [
        "var", "arg", "if", "while", "for", "forBy", "do", "collect",
        "select", "reject", "detect", "inject", "switch", "case",
        "loop", "repeat", "true", "false", "nil", "this", "thisProcess",
        "thisThread", "thisFunction", "inf", "pi", "super"
    ]

    let builtinClasses: Set<String> = [
        "SinOsc", "Saw", "Pulse", "LFSaw", "LFPulse", "LFNoise0", "LFNoise1",
        "WhiteNoise", "PinkNoise", "BrownNoise", "Dust",
        "SynthDef", "Synth", "Group", "Bus", "Buffer", "Server",
        "Pbind", "Pseq", "Prand", "Pdef", "Ppar", "Pfunc", "Pwhite",
        "Ndef", "NodeProxy", "ProxySpace", "Tdef",
        "EnvGen", "Env", "Line", "XLine",
        "LPF", "HPF", "BPF", "RLPF", "RHPF", "Resonz", "MoogFF",
        "Out", "In", "SoundIn", "LocalOut", "LocalIn",
        "Pan2", "Balance2", "Splay",
        "FreeVerb", "GVerb", "CombL", "CombC", "AllpassL", "AllpassC",
        "DelayL", "DelayC", "BufDelayL",
        "PlayBuf", "RecordBuf", "BufRd", "BufWr",
        "Mix", "MulAdd",
        "Routine", "Task", "TempoClock", "SystemClock", "AppClock",
        "OSCFunc", "OSCdef", "MIDIFunc", "MIDIdef", "MIDIClient",
        "NetAddr", "CmdPeriod",
        "Array", "List", "Dictionary", "Event",
        "MouseX", "MouseY",
        "FFT", "IFFT", "PV_MagFreeze", "PV_BrickWall",
        "Pitch", "Onsets", "BeatTrack",
        "GrainSin", "GrainBuf", "GrainFM",
        "Pluck", "DynKlang", "Klang",
        "DiskIn", "DiskOut", "VDiskIn",
        "Demand", "Dseq", "Drand", "Dwhite"
    ]

    func highlight(_ text: String, font: UIFont) -> NSAttributedString {
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: defaultColor
            ]
        )

        let nsText = text as NSString

        // Comments (line and block)
        highlightPattern(attr, nsText: nsText, pattern: "//[^\n]*", color: commentColor)
        highlightPattern(attr, nsText: nsText, pattern: "/\\*[\\s\\S]*?\\*/", color: commentColor)

        // Strings
        highlightPattern(attr, nsText: nsText, pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: stringColor)

        // Symbols
        highlightPattern(attr, nsText: nsText, pattern: "'[a-zA-Z_][a-zA-Z0-9_]*", color: symbolColor)
        highlightPattern(attr, nsText: nsText, pattern: "\\\\[a-zA-Z_][a-zA-Z0-9_]*", color: symbolColor)

        // Numbers
        highlightPattern(attr, nsText: nsText, pattern: "\\b\\d+\\.?\\d*\\b", color: numberColor)

        // Keywords
        for kw in keywords {
            highlightWord(attr, nsText: nsText, word: kw, color: keywordColor)
        }

        // Class names (capitalized identifiers)
        highlightPattern(attr, nsText: nsText, pattern: "\\b[A-Z][a-zA-Z0-9_]*\\b", color: classColor)

        return attr
    }

    private func highlightPattern(_ attr: NSMutableAttributedString, nsText: NSString, pattern: String, color: UIColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: nsText.length)
        for match in regex.matches(in: nsText as String, range: range) {
            attr.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }

    private func highlightWord(_ attr: NSMutableAttributedString, nsText: NSString, word: String, color: UIColor) {
        guard let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b") else { return }
        let range = NSRange(location: 0, length: nsText.length)
        for match in regex.matches(in: nsText as String, range: range) {
            attr.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
