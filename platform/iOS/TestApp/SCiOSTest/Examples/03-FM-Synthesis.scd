// ===================================
// FM Synthesis
// ===================================

// Simple 2-operator FM
(
{
    var mod = SinOsc.ar(200, 0, 300);
    SinOsc.ar(440 + mod, 0, 0.3) ! 2
}.play;
)

// Vibrato (slow FM)
(
{
    var vibrato = SinOsc.kr(5, 0, 10);
    SinOsc.ar(440 + vibrato, 0, 0.3) ! 2
}.play;
)

// 4-operator FM with envelope
(
{
    var env = EnvGen.kr(Env.perc(0.01, 2), doneAction: 2);
    var mod1 = SinOsc.ar(220, 0, 500 * env);
    var mod2 = SinOsc.ar(440, 0, 200 * env);
    var carrier = SinOsc.ar(110 + mod1 + mod2, 0, 0.3);
    carrier * env ! 2
}.play;
)

// FM bell
(
{
    var env = EnvGen.kr(Env.perc(0.001, 4), doneAction: 2);
    var mod = SinOsc.ar(280, 0, 1200 * env);
    var sig = SinOsc.ar(800 + mod, 0, 0.3);
    sig * env ! 2
}.play;
)

// Evolving FM texture
(
{
    var modFreq = LFNoise1.kr(0.2).range(100, 800);
    var modAmt = LFNoise1.kr(0.3).range(0, 500);
    var mod = SinOsc.ar(modFreq, 0, modAmt);
    var sig = SinOsc.ar(300 + mod, 0, 0.2);
    sig ! 2
}.play;
)

// Stop all sound
( CmdPeriod.run; )
