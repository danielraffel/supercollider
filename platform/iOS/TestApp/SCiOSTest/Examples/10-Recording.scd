// ===================================
// Recording & Buffers
// ===================================

// --- Record to file ---
// Records audio output to Documents/

// Start recording
s.record;

// Play something to record
{ SinOsc.ar(440, 0, 0.3) ! 2 }.play;

// Stop recording (saves to Documents/)
s.stopRecording;

// --- Buffer playback ---
// Allocate a buffer (1 second mono)
b = Buffer.alloc(s, 48000, 1);

// Fill with a sine wave
b.sine1([1, 0.5, 0.3, 0.1]);

// Play it
{ PlayBuf.ar(1, b, loop: 1) ! 2 * 0.3 }.play;

// --- Buffer-based looping ---
// Record synth output into a buffer, play it back
// (No mic input needed — records the synth output)

// Create a 4-second stereo buffer
~buf = Buffer.alloc(s, 48000 * 4, 2);

// Write a synth's output into the buffer
(
SynthDef(\loopRec, {|buf|
    var sig = SinOsc.ar(
        LFNoise0.kr(2).range(200, 800), 0, 0.3);
    RecordBuf.ar(sig ! 2, buf, loop: 1);
}).add;

SynthDef(\loopPlay, {|buf, amp=0.5|
    var sig = PlayBuf.ar(2, buf, loop: 1);
    Out.ar(0, sig * amp);
}).add;
)

// Record for a few seconds, then stop
x = Synth(\loopRec, [\buf, ~buf]);

// After a few seconds, free the recorder
// and start playback:
x.free;
y = Synth(\loopPlay, [\buf, ~buf]);

// Free when done
// y.free;
// ~buf.free;

// Stop all sound
( CmdPeriod.run; )
