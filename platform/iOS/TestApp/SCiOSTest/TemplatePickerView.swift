import SwiftUI

/// Template definitions — each creates a new .scd file with starter code
struct SCTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let iconColor: Color
    let category: String
    let description: String
    let code: String
}

let scTemplates: [SCTemplate] = [
    // Getting Started
    SCTemplate(
        name: "Tutorial",
        icon: "book.fill",
        iconColor: .orange,
        category: "Getting Started",
        description: "Step-by-step guide to SuperCollider basics",
        code: """
        // === SuperCollider Tutorial ===
        // Select a block (long-press) then tap Play or 2-finger tap

        // 1. Simple sine wave
        { SinOsc.ar(440, 0, 0.3) }.play;

        // 2. Two oscillators mixed
        (
        {
            var sig = SinOsc.ar(440, 0, 0.2) + SinOsc.ar(550, 0, 0.15);
            sig ! 2
        }.play;
        )

        // 3. With an envelope (fades out)
        (
        {
            var env = EnvGen.kr(Env.perc(0.01, 1.5), doneAction: 2);
            var sig = SinOsc.ar(660, 0, 0.3) * env;
            sig ! 2
        }.play;
        )

        // 4. Stop all sound
        CmdPeriod.run;
        """
    ),
    SCTemplate(
        name: "First Synth",
        icon: "waveform",
        iconColor: .green,
        category: "Getting Started",
        description: "Make your first sound with oscillators",
        code: """
        // === My First Synth ===

        // Simple tone
        { SinOsc.ar(440, 0, 0.3) ! 2 }.play;

        // Richer tone with overtones
        (
        {
            var fundamental = 220;
            var sig = SinOsc.ar(fundamental, 0, 0.2)
                + SinOsc.ar(fundamental * 2, 0, 0.1)
                + SinOsc.ar(fundamental * 3, 0, 0.05);
            sig ! 2
        }.play;
        )

        CmdPeriod.run;
        """
    ),

    // Synthesis
    SCTemplate(
        name: "SynthDef",
        icon: "waveform.path",
        iconColor: .blue,
        category: "Synthesis",
        description: "Reusable synth definition template",
        code: """
        // === SynthDef Template ===

        // Define the synth
        (
        SynthDef(\\mySynth, { |freq=440, amp=0.3, gate=1|
            var env = EnvGen.kr(Env.adsr(0.01, 0.1, 0.7, 0.3), gate, doneAction: 2);
            var sig = SinOsc.ar(freq, 0, amp) * env;
            Out.ar(0, sig ! 2);
        }).add;
        )

        // Play it
        x = Synth(\\mySynth, [\\freq, 440]);

        // Change parameters
        x.set(\\freq, 550);

        // Release
        x.set(\\gate, 0);

        CmdPeriod.run;
        """
    ),
    SCTemplate(
        name: "FM Synth",
        icon: "waveform.circle",
        iconColor: .purple,
        category: "Synthesis",
        description: "Frequency modulation synthesis",
        code: """
        // === FM Synthesis ===

        // Simple FM
        (
        {
            var modFreq = 200;
            var modAmp = 400;
            var mod = SinOsc.ar(modFreq, 0, modAmp);
            var carrier = SinOsc.ar(440 + mod, 0, 0.3);
            carrier ! 2
        }.play;
        )

        // FM with envelope
        (
        {
            var env = EnvGen.kr(Env.perc(0.01, 2), doneAction: 2);
            var modIndex = EnvGen.kr(Env([10, 1], [2]));
            var mod = SinOsc.ar(200, 0, 200 * modIndex);
            var sig = SinOsc.ar(440 + mod, 0, 0.3) * env;
            sig ! 2
        }.play;
        )

        CmdPeriod.run;
        """
    ),
    SCTemplate(
        name: "Subtractive",
        icon: "slider.horizontal.3",
        iconColor: .pink,
        category: "Synthesis",
        description: "Filter-based subtractive synthesis",
        code: """
        // === Subtractive Synthesis ===

        // Filtered sawtooth
        (
        {
            var sig = Saw.ar(110, 0.3);
            var filtered = LPF.ar(sig,
                LFNoise1.kr(0.5).range(200, 4000));
            filtered ! 2
        }.play;
        )

        // Resonant filter sweep
        (
        {
            var sig = Pulse.ar(55, 0.3, 0.3);
            var cutoff = LFSaw.kr(0.2).range(100, 5000);
            var filtered = RLPF.ar(sig, cutoff, 0.1);
            FreeVerb.ar(filtered, 0.3, 0.8) ! 2
        }.play;
        )

        CmdPeriod.run;
        """
    ),

    // Patterns
    SCTemplate(
        name: "Pbind",
        icon: "list.bullet.rectangle",
        iconColor: .orange,
        category: "Patterns",
        description: "Pattern-based sequencing with Pbind",
        code: """
        // === Pbind Pattern ===

        // Define a synth for the pattern
        (
        SynthDef(\\ping, { |freq=440, amp=0.3|
            var env = EnvGen.kr(Env.perc(0.01, 0.3), doneAction: 2);
            var sig = SinOsc.ar(freq, 0, amp) * env;
            Out.ar(0, sig ! 2);
        }).add;
        )

        // Simple melodic pattern
        (
        Pbind(
            \\instrument, \\ping,
            \\freq, Pseq([440, 550, 660, 880], inf),
            \\dur, 0.25,
            \\amp, 0.3
        ).play;
        )

        CmdPeriod.run;
        """
    ),
    SCTemplate(
        name: "Live Coding",
        icon: "repeat",
        iconColor: .green,
        category: "Patterns",
        description: "Ndef-based live coding setup",
        code: """
        // === Live Coding with Ndef ===

        // Start a sound — re-evaluate to change it live
        Ndef(\\live, { SinOsc.ar(440, 0, 0.2) ! 2 }).play;

        // Change it (re-evaluate this line)
        Ndef(\\live, { LPF.ar(Saw.ar(110, 0.3), LFNoise1.kr(0.5).range(200, 3000)) ! 2 });

        // Add effects
        Ndef(\\live, {
            var sig = Pulse.ar([110, 111], 0.3, 0.2);
            FreeVerb.ar(sig, 0.5, 0.8, 0.3)
        });

        // Fade out
        Ndef(\\live).stop(2);

        CmdPeriod.run;
        """
    ),

    // Effects
    SCTemplate(
        name: "Reverb Chain",
        icon: "sparkles",
        iconColor: .cyan,
        category: "Effects",
        description: "Effect chain with reverb and delay",
        code: """
        // === Effect Chain ===

        // Source → Delay → Reverb
        (
        {
            var src = Pulse.ar(220, 0.3, 0.15);
            var env = EnvGen.kr(Env.perc(0.01, 0.2),
                Impulse.kr(3));
            var delayed = CombL.ar(src * env, 0.5, 0.375, 3);
            var verb = FreeVerb.ar(delayed, 0.8, 0.9, 0.4);
            (verb + (src * env * 0.3)) ! 2
        }.play;
        )

        CmdPeriod.run;
        """
    ),
    SCTemplate(
        name: "Delay/Loop",
        icon: "infinity",
        iconColor: .purple,
        category: "Effects",
        description: "Feedback delay and looping effects",
        code: """
        // === Delay & Loop ===

        // Ping-pong delay
        (
        {
            var src = SinOsc.ar(
                LFNoise0.kr(2).range(400, 1200), 0, 0.15)
                * EnvGen.kr(Env.perc(0.01, 0.1), Impulse.kr(1));
            var left = CombL.ar(src, 1, 0.375, 6);
            var right = CombL.ar(src, 1, 0.25, 6);
            [left, right] + (src * 0.5)
        }.play;
        )

        CmdPeriod.run;
        """
    ),

    // Blank
    SCTemplate(
        name: "Blank",
        icon: "doc",
        iconColor: .gray,
        category: "Blank",
        description: "Empty .scd file",
        code: """
        // New SuperCollider script

        """
    ),
]

/// Groups templates by category
private var templateCategories: [(String, [SCTemplate])] {
    var dict: [String: [SCTemplate]] = [:]
    for t in scTemplates {
        dict[t.category, default: []].append(t)
    }
    let order = ["Getting Started", "Synthesis", "Patterns", "Effects", "Blank"]
    return order.compactMap { cat in
        dict[cat].map { (cat, $0) }
    }
}

struct TemplatePickerView: View {
    @EnvironmentObject var app: AppState
    @Binding var isPresented: Bool
    var onCreateFile: (String, String) -> Void  // (filename, content) -> open it

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(templateCategories, id: \.0) { category, templates in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category)
                                .font(.title2.weight(.bold))
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(templates) { template in
                                    Button {
                                        createFromTemplate(template)
                                    } label: {
                                        templateCard(template)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Choose a Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func templateCard(_ template: SCTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: template.icon)
                .font(.title2)
                .foregroundColor(template.iconColor)

            Text(template.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            Text(template.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func createFromTemplate(_ template: SCTemplate) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let safeName = template.name
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "\(safeName)_\(timestamp).scd"
        onCreateFile(filename, template.code)
        isPresented = false
    }
}
