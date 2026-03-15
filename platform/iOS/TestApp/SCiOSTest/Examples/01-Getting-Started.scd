// ===================================
// SuperCollider for iOS
// Getting Started
// ===================================

// Welcome! This tutorial will get you
// making sound in minutes.

// HOW TO USE:
// Select code and press ⌘+Return to evaluate
// Press ⌘+. to stop all sound

// --- 1. Your First Sound ---
// Evaluate this line:
{ SinOsc.ar(440, 0, 0.3) }.play;

// Stop it:
CmdPeriod.run;

// --- 2. Changing Pitch ---
{ SinOsc.ar(880, 0, 0.3) }.play;

// --- 3. Multiple Oscillators ---
(
{
    var sig = SinOsc.ar(440, 0, 0.1)
        + SinOsc.ar(550, 0, 0.1)
        + SinOsc.ar(660, 0, 0.1);
    sig
}.play;
)

// --- 4. FM Synthesis ---
(
{
    var mod = SinOsc.ar(200, 0, 100);
    SinOsc.ar(440 + mod, 0, 0.3)
}.play;
)

// --- 5. Filtered Noise ---
(
{
    var noise = WhiteNoise.ar(0.5);
    RLPF.ar(noise, MouseX.kr(200, 5000), 0.1)
}.play;
)

// --- 6. Using SynthDef ---
(
SynthDef(\ping, {|freq=440, amp=0.3, dur=0.3|
    var env = EnvGen.kr(Env.perc(0.01, dur), doneAction: 2);
    var sig = SinOsc.ar(freq, 0, amp) * env;
    Out.ar(0, sig ! 2);
}).add;
)

// Play the SynthDef:
Synth(\ping, [\freq, 660, \amp, 0.5]);
Synth(\ping, [\freq, 880, \amp, 0.3]);

// --- 7. Patterns ---
(
Pbind(
    \instrument, \ping,
    \freq, Pseq([440, 550, 660, 880], inf),
    \dur, 0.25,
    \amp, 0.3
).play;
)

// Stop:
CmdPeriod.run;

// --- 8. Reverb Effect ---
(
{
    var sig = Pulse.ar(220, 0.5, 0.2);
    FreeVerb.ar(sig, 0.8, 0.9, 0.3) ! 2
}.play;
)

// Congratulations! You're making music
// with SuperCollider on iOS!
//
// Explore more in the SC documentation
// and community at supercollider.github.io
