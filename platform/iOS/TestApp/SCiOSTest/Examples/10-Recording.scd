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

// --- Live looping ---
// Record into a buffer, play it back

// Create a 4-second stereo buffer
~buf = Buffer.alloc(s, 48000 * 4, 2);

// Record synth output into buffer
(
SynthDef(\loopRec, {|buf, in=0|
    RecordBuf.ar(
        SoundIn.ar([0, 0]),  // mic input
        buf, loop: 1
    );
}).add;
)

// Play back the buffer
(
SynthDef(\loopPlay, {|buf, amp=0.5|
    var sig = PlayBuf.ar(2, buf, loop: 1);
    Out.ar(0, sig * amp);
}).add;
)

// Start recording (needs mic permission)
// Synth(\loopRec, [\buf, ~buf]);

// Start playback
// Synth(\loopPlay, [\buf, ~buf]);

// Free buffer when done
// ~buf.free;

CmdPeriod.run;
