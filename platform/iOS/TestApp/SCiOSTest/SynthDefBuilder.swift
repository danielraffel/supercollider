import Foundation

/// Builds minimal SynthDef binary data for use without sclang.
/// SynthDef file format v2 (SC 3.x)
struct SynthDefBuilder {
    /// Build a simple sine wave SynthDef: Out.ar(out, SinOsc.ar(freq) * amp)
    /// Parameters: out (bus), freq (Hz), amp (volume)
    static func simpleSine(name: String = "sc_sine") -> Data {
        var d = Data()

        // File header
        d.append(contentsOf: "SCgf".utf8)           // magic
        d.appendInt32(2)                              // version 2
        d.appendInt16(1)                              // 1 synthdef

        // SynthDef name
        d.appendPascalString(name)

        // Constants (values used by UGens)
        d.appendInt32(2)                              // 2 constants
        d.appendFloat32(0.0)                          // const 0: 0.0 (default out bus, phase)
        d.appendFloat32(440.0)                        // const 1: 440.0 (not used as default, but available)

        // Parameters (control inputs)
        d.appendInt32(3)                              // 3 parameter values
        d.appendFloat32(0.0)                          // param 0: out = 0
        d.appendFloat32(440.0)                        // param 1: freq = 440
        d.appendFloat32(0.3)                          // param 2: amp = 0.3

        // Parameter names
        d.appendInt32(3)                              // 3 parameter names
        d.appendPascalString("out")
        d.appendInt32(0)                              // index 0
        d.appendPascalString("freq")
        d.appendInt32(1)                              // index 1
        d.appendPascalString("amp")
        d.appendInt32(2)                              // index 2

        // UGens
        d.appendInt32(4)                              // 4 UGens

        // UGen 0: Control.kr (outputs the 3 parameters)
        d.appendPascalString("Control")
        d.appendInt8(1)                               // rate: control (1)
        d.appendInt32(0)                              // 0 inputs
        d.appendInt32(3)                              // 3 outputs (out, freq, amp)
        d.appendInt16(0)                              // special index 0
        // Output rates: all control rate
        d.appendInt8(1)                               // out: control rate
        d.appendInt8(1)                               // freq: control rate
        d.appendInt8(1)                               // amp: control rate

        // UGen 1: SinOsc.ar(freq, 0)
        d.appendPascalString("SinOsc")
        d.appendInt8(2)                               // rate: audio (2)
        d.appendInt32(2)                              // 2 inputs (freq, phase)
        d.appendInt32(1)                              // 1 output
        d.appendInt16(0)                              // special index 0
        // Input 0: freq from Control output 1
        d.appendInt32(0)                              // UGen index 0 (Control)
        d.appendInt32(1)                              // output index 1 (freq)
        // Input 1: phase = constant 0.0
        d.appendInt32(-1)                             // -1 = constant
        d.appendInt32(0)                              // constant index 0 (0.0)
        // Output rate
        d.appendInt8(2)                               // audio rate

        // UGen 2: BinaryOpUGen.ar (multiply: SinOsc * amp)
        d.appendPascalString("BinaryOpUGen")
        d.appendInt8(2)                               // rate: audio (2)
        d.appendInt32(2)                              // 2 inputs
        d.appendInt32(1)                              // 1 output
        d.appendInt16(2)                              // special index 2 = multiply
        // Input 0: SinOsc output
        d.appendInt32(1)                              // UGen index 1 (SinOsc)
        d.appendInt32(0)                              // output index 0
        // Input 1: amp from Control output 2
        d.appendInt32(0)                              // UGen index 0 (Control)
        d.appendInt32(2)                              // output index 2 (amp)
        // Output rate
        d.appendInt8(2)                               // audio rate

        // UGen 3: Out.ar(out, signal) — mono to both channels
        d.appendPascalString("Out")
        d.appendInt8(2)                               // rate: audio (2)
        d.appendInt32(2)                              // 2 inputs (bus, signal)
        d.appendInt32(0)                              // 0 outputs
        d.appendInt16(0)                              // special index 0
        // Input 0: bus from Control output 0
        d.appendInt32(0)                              // UGen index 0 (Control)
        d.appendInt32(0)                              // output index 0 (out)
        // Input 1: signal from BinaryOpUGen
        d.appendInt32(2)                              // UGen index 2 (BinaryOpUGen)
        d.appendInt32(0)                              // output index 0

        // Variants (none)
        d.appendInt16(0)

        return d
    }
}

// MARK: - Data helpers for SynthDef binary format

private extension Data {
    mutating func appendInt8(_ v: Int8) {
        var val = v
        append(Data(bytes: &val, count: 1))
    }

    mutating func appendUInt8(_ v: UInt8) {
        var val = v
        append(Data(bytes: &val, count: 1))
    }

    mutating func appendInt16(_ v: Int16) {
        var big = v.bigEndian
        append(Data(bytes: &big, count: 2))
    }

    mutating func appendInt32(_ v: Int32) {
        var big = v.bigEndian
        append(Data(bytes: &big, count: 4))
    }

    mutating func appendFloat32(_ v: Float32) {
        var big = v.bitPattern.bigEndian
        append(Data(bytes: &big, count: 4))
    }

    mutating func appendPascalString(_ s: String) {
        let bytes = Array(s.utf8)
        appendUInt8(UInt8(bytes.count))
        append(contentsOf: bytes)
    }
}
