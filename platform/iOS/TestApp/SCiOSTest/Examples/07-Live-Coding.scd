// ===================================
// Live Coding with Ndef
// ===================================

// Ndef creates named synths you can
// replace while they're playing.

// Start a simple tone
Ndef(\a, { SinOsc.ar(440, 0, 0.3) ! 2 }).play;

// Replace it — crossfades automatically!
Ndef(\a, { Saw.ar(220, 0.2) ! 2 });

// Add filtering
Ndef(\a, { RLPF.ar(Saw.ar(220, 0.3), 800, 0.2) ! 2 });

// Make the filter sweep
(
Ndef(\a, {
    RLPF.ar(
        Saw.ar(220, 0.3),
        LFNoise1.kr(0.5).range(200, 3000),
        0.1
    ) ! 2
});
)

// Add reverb
(
Ndef(\a, {
    var sig = RLPF.ar(
        Saw.ar([220, 221], 0.2),
        LFNoise1.kr(0.3).range(300, 2000),
        0.1
    );
    FreeVerb.ar(sig, 0.6, 0.8, 0.3)
});
)

// Layer another sound
Ndef(\b, { PinkNoise.ar(0.05) ! 2 }).play;

// Stop individually
Ndef(\a).stop;
Ndef(\b).stop;

// Or stop everything
// Stop all sound
( CmdPeriod.run; )
