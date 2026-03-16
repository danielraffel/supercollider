// ===================================
// Ambient & Drone
// ===================================

// --- Simple drone ---
(
{
    var sig = Mix([
        SinOsc.ar(110, 0, 0.15),
        SinOsc.ar(165, 0, 0.1),
        SinOsc.ar(220, 0, 0.08),
        SinOsc.ar(330, 0, 0.05)
    ]);
    FreeVerb.ar(sig, 0.9, 0.95, 0.3) ! 2
}.play;
)

// --- Evolving pad ---
(
{
    var freqs = [220, 277, 330, 440];
    var sig = Mix(freqs.collect { |f|
        SinOsc.ar(f + LFNoise1.kr(0.1).range(-2, 2),
            0, 0.1)
    });
    var filtered = LPF.ar(sig,
        LFNoise1.kr(0.2).range(500, 3000));
    FreeVerb.ar(filtered, 0.85, 0.9, 0.4) ! 2
}.play;
)

// --- Wind texture ---
(
{
    var wind = BPF.ar(
        PinkNoise.ar(0.3),
        LFNoise1.kr(0.1).range(200, 2000),
        0.05
    );
    FreeVerb.ar(wind, 0.9, 0.95, 0.5) ! 2
}.play;
)

// --- Crystalline ---
(
{
    var trig = Dust.kr(2);
    var freq = TChoose.kr(trig,
        [440, 554, 659, 880, 1108, 1318]);
    var sig = SinOsc.ar(freq, 0, 0.2);
    var env = EnvGen.kr(Env.perc(0.01, 2), trig);
    FreeVerb.ar(sig * env, 0.9, 0.95, 0.3) ! 2
}.play;
)

// --- Tape loop ---
(
{
    var sig = SinOsc.ar(
        LFNoise0.kr(0.5).range(200, 800), 0, 0.1);
    var delay = CombL.ar(sig, 2, 1.5, 8);
    var verb = FreeVerb.ar(delay, 0.7, 0.8, 0.4);
    verb + (sig * 0.3) ! 2
}.play;
)

CmdPeriod.run;
