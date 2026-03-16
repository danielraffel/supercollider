// ===================================
// Drum Synthesis
// ===================================

// All drums use doneAction: 2 so they
// free themselves after playing.

// --- Kick ---
(
{
    var env = EnvGen.kr(Env.perc(0.001, 0.3), doneAction: 2);
    var freq = EnvGen.kr(Env([1000, 60, 30], [0.01, 0.2]));
    var sig = SinOsc.ar(freq, 0, 0.8) * env;
    sig ! 2
}.play;
)

// --- Snare ---
(
{
    var env = EnvGen.kr(Env.perc(0.001, 0.2), doneAction: 2);
    var tone = SinOsc.ar(200, 0, 0.3) * env;
    var noise = WhiteNoise.ar(0.5) * EnvGen.kr(Env.perc(0.001, 0.15));
    var sig = tone + noise;
    HPF.ar(sig, 200) * env ! 2
}.play;
)

// --- Hi-hat ---
(
{
    var env = EnvGen.kr(Env.perc(0.001, 0.08), doneAction: 2);
    var sig = HPF.ar(WhiteNoise.ar(0.3), 8000) * env;
    sig ! 2
}.play;
)

// --- Clap ---
(
{
    var env = EnvGen.kr(Env.perc(0.001, 0.15), doneAction: 2);
    var noise = BPF.ar(WhiteNoise.ar, 1200, 0.5, 3) * env;
    noise ! 2
}.play;
)

// --- Drum pattern ---
// First define the drum SynthDefs
(
SynthDef(\kick, {
    var env = EnvGen.kr(Env.perc(0.001, 0.3), doneAction: 2);
    var freq = EnvGen.kr(Env([1000, 60, 30], [0.01, 0.2]));
    Out.ar(0, SinOsc.ar(freq, 0, 0.8) * env ! 2);
}).add;

SynthDef(\snare, {
    var env = EnvGen.kr(Env.perc(0.001, 0.2), doneAction: 2);
    var tone = SinOsc.ar(200, 0, 0.3) * env;
    var noise = WhiteNoise.ar(0.5) * EnvGen.kr(Env.perc(0.001, 0.15));
    Out.ar(0, HPF.ar(tone + noise, 200) * env ! 2);
}).add;

SynthDef(\hat, {
    var env = EnvGen.kr(Env.perc(0.001, 0.08), doneAction: 2);
    Out.ar(0, HPF.ar(WhiteNoise.ar(0.3), 8000) * env ! 2);
}).add;
)

// Play a simple beat
(
Ppar([
    Pbind(\instrument, \kick,
        \dur, 1,
        \amp, 0.8),
    Pbind(\instrument, \snare,
        \dur, 1,
        \amp, 0.5,
        \lag, 0.5),
    Pbind(\instrument, \hat,
        \dur, 0.25,
        \amp, 0.3)
]).play;
)

CmdPeriod.run;
