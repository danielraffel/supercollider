import SwiftUI
import AVFoundation

/// Lightweight recording playback sheet
struct RecordingPlayerView: View {
    let recording: SCFileManager.Recording
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = AudioPlayer()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header info
                VStack(spacing: 6) {
                    Text(recording.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Text(recording.size)
                        Text("WAV")
                        Text(recording.date, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    // Source patch link
                    if let patchName = extractPatchName(from: recording.name) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                            Text("From: \(patchName).scd")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 8)

                // Progress bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill(Color(.systemGray4))
                                .frame(height: 6)

                            // Progress
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: max(0, geo.size.width * player.progress), height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text(player.currentTimeString)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(player.remainingTimeString)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)

                // Playback controls
                HStack(spacing: 40) {
                    Button {
                        player.seek(by: -10)
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.orange)
                    }

                    Button {
                        player.seek(by: 10)
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 24) {
                    ShareLink(item: recording.url) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                            Text("Share")
                                .font(.caption2)
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                player.load(url: recording.url)
            }
            .onDisappear {
                player.stop()
            }
        }
    }

    private func extractPatchName(from filename: String) -> String? {
        // "06-Ambient_260316_154840.wav" → "06-Ambient"
        let base = filename.replacingOccurrences(of: ".wav", with: "")
            .replacingOccurrences(of: ".aiff", with: "")
        let parts = base.components(separatedBy: "_")
        // Need at least 3 parts: name, date, time
        guard parts.count >= 3 else { return nil }
        // Everything before the last two parts (date_time) is the patch name
        let nameparts = parts.dropLast(2)
        let name = nameparts.joined(separator: "_")
        return name.isEmpty ? nil : name
    }
}

/// Simple AVAudioPlayer wrapper
class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTimeString = "0:00"
    @Published var remainingTimeString = "0:00"

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            updateTimeDisplay()
        } catch {
            print("AudioPlayer load error: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateTimeDisplay()
            }
        }
    }

    func stop() {
        audioPlayer?.stop()
        timer?.invalidate()
        isPlaying = false
    }

    func seek(by seconds: Double) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(player.duration, player.currentTime + seconds))
        player.currentTime = newTime
        updateTimeDisplay()
    }

    private func updateTimeDisplay() {
        guard let player = audioPlayer else { return }
        let current = player.currentTime
        let duration = player.duration
        progress = duration > 0 ? current / duration : 0
        currentTimeString = formatTime(current)
        remainingTimeString = "-\(formatTime(duration - current))"

        if !player.isPlaying && current >= duration && duration > 0 {
            isPlaying = false
            timer?.invalidate()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
