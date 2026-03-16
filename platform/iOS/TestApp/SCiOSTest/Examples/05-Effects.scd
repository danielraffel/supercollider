// ===================================
// Effects & Processing
// ===================================

// --- Reverb ---
(
{
    var sig = Pulse.ar(220, 0.5, 0.2);
    FreeVerb.ar(sig, 0.8, 0.9, 0.3) ! 2
}.play;
)

// --- Delay ---
(
{
    var sig = Dust.ar(3) * 0.5;
    sig = sig + CombL.ar(sig, 0.5, 0.3, 4);
    sig ! 2
}.play;
)

// --- Ping-pong delay ---
(
{
    var sig = Impulse.ar(2) * SinOsc.ar(880, 0, 0.3);
    var left = CombL.ar(sig, 0.5, 0.25, 3);
    var right = CombL.ar(sig, 0.5, 0.375, 3);
    [left, right] * 0.5
}.play;
)

// --- Chorus ---
(
{
    var sig = Saw.ar(220, 0.2);
    var chorus = Mix.fill(4, {
        var dt = LFNoise1.kr(0.5).range(0.01, 0.03);
        DelayL.ar(sig, 0.05, dt)
    });
    (sig + (chorus * 0.3)) ! 2
}.play;
)

// --- Distortion ---
(
{
    var sig = SinOsc.ar(110, 0, 0.8);
    sig = (sig * 10).tanh * 0.3;
    sig ! 2
}.play;
)

// --- Filter sweep ---
(
{
    var sig = Saw.ar([110, 111], 0.3);
    var freq = LFNoise1.kr(0.3).range(200, 4000);
    RLPF.ar(sig, freq, 0.1)
}.play;
)

// --- Granular shimmer ---
(
{
    var sig = PinkNoise.ar(0.1);
    var grains = GrainIn.ar(2, Dust.kr(20), 0.05, sig);
    FreeVerb.ar(grains, 0.9, 0.95, 0.5)
}.play;
)

CmdPeriod.run;
