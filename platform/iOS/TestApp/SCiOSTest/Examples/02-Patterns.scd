// ===================================
// Patterns & Sequencing
// ===================================

// Patterns are SC's powerful sequencing system.

// First, define some instruments:
(
SynthDef(\sine, {|freq=440, amp=0.3, dur=0.3|
    var env = EnvGen.kr(Env.perc(0.01, dur), doneAction: 2);
    Out.ar(0, SinOsc.ar(freq, 0, amp * env) ! 2);
}).add;

SynthDef(\saw, {|freq=440, amp=0.2, dur=0.3|
    var env = EnvGen.kr(Env.perc(0.01, dur), doneAction: 2);
    var sig = Saw.ar(freq, amp) * env;
    Out.ar(0, RLPF.ar(sig, freq * 3, 0.3) ! 2);
}).add;
)

// Simple sequence:
(
Pbind(
    \instrument, \sine,
    \freq, Pseq([440, 550, 660, 880], inf),
    \dur, 0.25,
    \amp, 0.3
).play;
)

// Random melody:
(
Pbind(
    \instrument, \saw,
    \midinote, Prand([60, 62, 64, 67, 69, 72], inf),
    \dur, Prand([0.125, 0.25, 0.5], inf),
    \amp, 0.2
).play;
)

// Two patterns together:
(
Ppar([
    Pbind(
        \instrument, \sine,
        \midinote, Pseq([72, 71, 69, 67], inf),
        \dur, 0.5,
        \amp, 0.2
    ),
    Pbind(
        \instrument, \saw,
        \midinote, Pseq([48, 48, 55, 55], inf),
        \dur, 1,
        \amp, 0.15
    )
]).play;
)

CmdPeriod.run;
