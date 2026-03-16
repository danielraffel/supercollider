// ===================================
// MIDI & OSC
// ===================================

// --- MIDI Input ---
// Connect a Bluetooth or USB MIDI controller

// Initialize MIDI
MIDIClient.init;
MIDIIn.connectAll;

// Define a synth for MIDI notes
(
SynthDef(\midiSynth, {|freq=440, amp=0.3, gate=1|
    var env = EnvGen.kr(
        Env.adsr(0.01, 0.1, 0.7, 0.3),
        gate, doneAction: 2);
    var sig = Saw.ar(freq, amp) * env;
    Out.ar(0, RLPF.ar(sig, freq * 3, 0.2) ! 2);
}).add;
)

// Respond to note on/off
(
MIDIdef.noteOn(\on, { |vel, note|
    Synth(\midiSynth, [
        \freq, note.midicps,
        \amp, vel / 127 * 0.5
    ]);
    ("Note ON: " ++ note ++ " vel: " ++ vel).postln;
});

MIDIdef.noteOff(\off, { |vel, note|
    ("Note OFF: " ++ note).postln;
});

MIDIdef.cc(\knob, { |val, num|
    ("CC " ++ num ++ ": " ++ val).postln;
});
)

// Free MIDI responders
MIDIdef.freeAll;

// --- OSC ---
// Receive OSC from other apps or desktop SC

// Open a port for receiving
thisProcess.openUDPPort(57120);

// Respond to /note messages
(
OSCdef(\note, { |msg|
    var freq = msg[1];
    var amp = msg[2] ? 0.3;
    { SinOsc.ar(freq, 0, amp)
        * EnvGen.kr(Env.perc, doneAction: 2)
        ! 2
    }.play;
    ("OSC /note: " ++ freq ++ " Hz").postln;
}, '/note');
)

// Send from desktop SC:
// n = NetAddr("iPhone-IP", 57120);
// n.sendMsg('/note', 440, 0.5);

// Free OSC responders
OSCdef.freeAll;

CmdPeriod.run;
