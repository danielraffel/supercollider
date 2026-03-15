// SuperCollider iOS — SynthDef Compilation Script
// Run with desktop sclang to produce .scsyndef files for iOS
//
// Usage: sclang compile_synthdefs.scd
// Output: .scsyndef files in the same directory

(
var outDir = PathName(thisProcess.nowExecutingPath).pathOnly;

// === Sine wave (simple test) ===
SynthDef(\sine, { |out=0, freq=440, amp=0.3|
    Out.ar(out, SinOsc.ar(freq, 0, amp) ! 2);
}).writeDefFile(outDir);

// === Ping (percussive) ===
SynthDef(\ping, { |out=0, freq=440, amp=0.5, gate=1|
    var env = EnvGen.kr(Env.perc(0.01, 0.3), gate, doneAction: 2);
    Out.ar(out, SinOsc.ar(freq, 0, amp * env) ! 2);
}).writeDefFile(outDir);

// === FM synthesis ===
SynthDef(\fm, { |out=0, freq=440, modFreq=200, modIndex=3, amp=0.3, gate=1|
    var env = EnvGen.kr(Env.adsr(0.01, 0.3, 0.5, 0.5), gate, doneAction: 2);
    var mod = SinOsc.ar(modFreq) * modIndex * modFreq;
    var car = SinOsc.ar(freq + mod, 0, amp * env);
    Out.ar(out, car ! 2);
}).writeDefFile(outDir);

// === Noise (white noise with filter) ===
SynthDef(\noise, { |out=0, freq=1000, rq=0.5, amp=0.3|
    Out.ar(out, BPF.ar(WhiteNoise.ar(amp), freq, rq) ! 2);
}).writeDefFile(outDir);

// === Filter (resonant lowpass sweep) ===
SynthDef(\filter, { |out=0, freq=440, cutoff=2000, rq=0.3, amp=0.3, gate=1|
    var env = EnvGen.kr(Env.adsr(0.01, 0.2, 0.7, 0.5), gate, doneAction: 2);
    var sig = Saw.ar(freq, amp);
    sig = RLPF.ar(sig, cutoff, rq);
    Out.ar(out, sig * env ! 2);
}).writeDefFile(outDir);

// === PlayBuf (buffer playback) ===
SynthDef(\playbuf, { |out=0, buf=0, rate=1, amp=1, loop=0|
    var sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, loop: loop, doneAction: 2);
    Out.ar(out, sig * amp ! 2);
}).writeDefFile(outDir);

// === SoundIn (microphone input passthrough) ===
SynthDef(\soundin, { |out=0, amp=1|
    Out.ar(out, SoundIn.ar([0, 1]) * amp);
}).writeDefFile(outDir);

"=== SynthDefs compiled to: ".post; outDir.postln;
"=== Files:".postln;
PathName(outDir).files.do { |f|
    if(f.extension == "scsyndef") { f.fileName.postln };
};
0.exit;
)
