import Foundation

/// Builds minimal SynthDef binary data for use without sclang.
/// SynthDef file format v2 (SC 3.x)
struct SynthDefBuilder {
    /// Build an 8-operator FM synthesis SynthDef.
    /// Linear chain: op8 modulates op7, op7 modulates op6, ..., op1 outputs.
    /// Each operator is a SinOsc at freq*ratio, with the previous operator's output
    /// added as frequency modulation. Op1 outputs to audio bus.
    /// Parameters: freq (base Hz), amp (output volume), index (modulation depth)
    static func fm8Operators(name: String = "sc_fm8") -> Data {
        var d = Data()

        // Header
        d.append(contentsOf: "SCgf".utf8)
        d.appendInt32(2)                              // version 2
        d.appendInt16(1)                              // 1 synthdef
        d.appendPascalString(name)

        // Constants: 0.0 through 8.0 (phase=0, operator frequency ratios)
        d.appendInt32(9)
        for i in 0...8 { d.appendFloat32(Float32(i)) }

        // Parameters: freq=440, amp=0.1, index=1.0
        d.appendInt32(3)
        d.appendFloat32(440.0)
        d.appendFloat32(0.1)
        d.appendFloat32(1.0)

        // Parameter names
        d.appendInt32(3)
        d.appendPascalString("freq"); d.appendInt32(0)
        d.appendPascalString("amp"); d.appendInt32(1)
        d.appendPascalString("index"); d.appendInt32(2)

        // UGen graph: 33 UGens total
        // UGen 0: Control (3 outputs)
        // Op8: UGens 1-3 (freqMul, SinOsc, scale) — 3 UGens, no modulator input
        // Ops 7-1: UGens 4-31 (freqMul, addMod, SinOsc, scale) — 4 UGens each, 7 ops
        // UGen 32: Out
        // Total: 1 + 3 + 7*4 + 1 = 33
        d.appendInt32(33)

        // UGen 0: Control.kr (3 outputs: freq[0], amp[1], index[2])
        d.appendPascalString("Control")
        d.appendInt8(1)                               // control rate
        d.appendInt32(0)                              // 0 inputs
        d.appendInt32(3)                              // 3 outputs
        d.appendInt16(0)                              // special index 0
        d.appendInt8(1); d.appendInt8(1); d.appendInt8(1)

        var ugen: Int32 = 1
        var prevScaleUGen: Int32 = -1

        for opNum in stride(from: 8, through: 1, by: -1) {
            let isFirst = (opNum == 8)
            let isLast = (opNum == 1)

            // BinaryOpUGen.kr: freq * ratio (freq * opNum)
            let freqMulUGen = ugen
            d.appendPascalString("BinaryOpUGen")
            d.appendInt8(1)                           // control rate
            d.appendInt32(2); d.appendInt32(1); d.appendInt16(2)
            d.appendInt32(0); d.appendInt32(0)        // in0: Control[freq]
            d.appendInt32(-1); d.appendInt32(Int32(opNum)) // in1: const[opNum]
            d.appendInt8(1)
            ugen += 1

            var sinFreqUGen = freqMulUGen

            if !isFirst {
                // BinaryOpUGen.ar: (freq*ratio) + modulator_output
                let addModUGen = ugen
                d.appendPascalString("BinaryOpUGen")
                d.appendInt8(2)                       // audio rate
                d.appendInt32(2); d.appendInt32(1); d.appendInt16(0) // add
                d.appendInt32(freqMulUGen); d.appendInt32(0)  // in0: freq*ratio
                d.appendInt32(prevScaleUGen); d.appendInt32(0) // in1: prev op output
                d.appendInt8(2)
                ugen += 1
                sinFreqUGen = addModUGen
            }

            // SinOsc.ar(modulated_freq, phase=0)
            let sinUGen = ugen
            d.appendPascalString("SinOsc")
            d.appendInt8(2)                           // audio rate
            d.appendInt32(2); d.appendInt32(1); d.appendInt16(0)
            d.appendInt32(sinFreqUGen); d.appendInt32(0) // in0: freq input
            d.appendInt32(-1); d.appendInt32(0)       // in1: const[0] = 0.0 (phase)
            d.appendInt8(2)
            ugen += 1

            // BinaryOpUGen.ar: SinOsc * scale (amp for op1, index for others)
            let scaleUGen = ugen
            d.appendPascalString("BinaryOpUGen")
            d.appendInt8(2)                           // audio rate
            d.appendInt32(2); d.appendInt32(1); d.appendInt16(2) // multiply
            d.appendInt32(sinUGen); d.appendInt32(0)  // in0: SinOsc output
            if isLast {
                d.appendInt32(0); d.appendInt32(1)    // in1: Control[amp]
            } else {
                d.appendInt32(0); d.appendInt32(2)    // in1: Control[index]
            }
            d.appendInt8(2)
            ugen += 1

            prevScaleUGen = scaleUGen
        }

        // UGen 32: Out.ar(bus=0, signal)
        d.appendPascalString("Out")
        d.appendInt8(2)                               // audio rate
        d.appendInt32(2); d.appendInt32(0); d.appendInt16(0) // 2 inputs, 0 outputs
        d.appendInt32(-1); d.appendInt32(0)           // in0: const[0] = bus 0
        d.appendInt32(prevScaleUGen); d.appendInt32(0) // in1: final op output

        // No variants
        d.appendInt16(0)

        return d
    }

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
