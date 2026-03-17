// ===================================
// Granular Synthesis
// ===================================

// --- Grain cloud from sine ---
(
{
    GrainSin.ar(
        numChannels: 2,
        trigger: Dust.kr(20),
        dur: 0.05,
        freq: LFNoise0.kr(4).range(400, 1200)
    ) * 0.3
}.play;
)

// --- Dense grain texture ---
(
{
    var trig = Dust.kr(40);
    var freq = TChoose.kr(trig,
        [220, 330, 440, 550, 660, 880]);
    var sig = GrainSin.ar(2, trig, 0.02, freq);
    FreeVerb.ar(sig * 0.3, 0.8, 0.9, 0.4)
}.play;
)

// --- Granular with FM grains ---
(
{
    var trig = Impulse.kr(15);
    var freq = LFNoise1.kr(0.3).range(200, 600);
    var sig = GrainFM.ar(
        numChannels: 2,
        trigger: trig,
        dur: 0.1,
        carfreq: freq,
        modfreq: freq * 2,
        index: LFNoise1.kr(0.5).range(1, 8)
    );
    FreeVerb.ar(sig * 0.3, 0.7, 0.85, 0.4)
}.play;
)

// --- Glitchy micro-grains ---
(
{
    var rate = LFNoise1.kr(0.2).range(5, 60);
    var trig = Dust.kr(rate);
    var freq = TChoose.kr(trig,
        [110, 220, 440, 880, 1760]);
    var dur = TRand.kr(0.005, 0.05, trig);
    var sig = GrainSin.ar(2, trig, dur, freq);
    (sig * 0.4).tanh
}.play;
)

// Stop all sound
( CmdPeriod.run; )
