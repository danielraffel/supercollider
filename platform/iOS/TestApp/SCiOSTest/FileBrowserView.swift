import SwiftUI

/// File browser with segmented tabs: Scripts / Recordings / Examples
struct FileBrowserView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var showImporter = false
    @State private var showTemplates = false
    @State private var selectedRecording: SCFileManager.Recording? = nil
    @State private var selectedTab = 0  // 0=Scripts, 1=Recordings, 2=Examples

    var body: some View {
        VStack(spacing: 0) {
            // Hero header
            heroHeader
                .padding(.bottom, 4)

            // Segmented control
            Picker("", selection: $selectedTab) {
                Text("Scripts").tag(0)
                Text("Recordings").tag(1)
                Text("Examples").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Tab content
            switch selectedTab {
            case 0:
                scriptsTab
                    .onAppear { fileManager.refreshFileList() }
            case 1:
                recordingsTab
                    .onAppear { fileManager.refreshRecordings() }
            case 2:
                examplesTab
                    .onAppear { fileManager.refreshFileList() }
            default:
                scriptsTab
            }
        }
        .onAppear {
            fileManager.refreshRecordings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scRecordingFinished)) { _ in
            fileManager.refreshRecordings()
        }
        .scDocumentImporter(isPresented: $showImporter) { url in
            importFile(from: url)
        }
        .alert("New Script", isPresented: $showNewFileAlert) {
            TextField("filename.scd", text: $newFileName)
            Button("Create") {
                if let file = fileManager.createFile(name: newFileName) {
                    openFile(file)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showTemplates) {
            TemplatePickerView(isPresented: $showTemplates) { filename, content in
                if let file = fileManager.createFile(name: filename) {
                    let _ = fileManager.saveFile(file, content: content)
                    openFile(file)
                    app.isEditing = true
                }
            }
            .environmentObject(app)
        }
        .sheet(item: $selectedRecording) { rec in
            RecordingPlayerView(recording: rec)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Scripts Tab

    var scriptsTab: some View {
        List {
            ForEach(fileManager.files.filter { !$0.isExample }) { file in
                Button {
                    openFile(file)
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(file.name)
                        Spacer()
                        if file.path == app.currentFile {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        let _ = fileManager.deleteFile(file)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if fileManager.files.filter({ !$0.isExample }).isEmpty {
                Text("No scripts yet.\nTap + to create one or use a template.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Recordings Tab

    var recordingsTab: some View {
        List {
            if fileManager.recordings.isEmpty {
                Text("No recordings yet.\nTap the record button in the editor to start.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(fileManager.recordings) { rec in
                    Button {
                        selectedRecording = rec
                    } label: {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.name)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(rec.duration)
                                    Text(rec.size)
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle")
                                .foregroundColor(.orange)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            let _ = fileManager.deleteRecording(rec)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        ShareLink(item: rec.url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Examples Tab

    var examplesTab: some View {
        List {
            ForEach(fileManager.files.filter { $0.isExample }) { file in
                Button {
                    openFile(file)
                } label: {
                    HStack {
                        Text(file.name)
                        Spacer()
                        if file.path == app.currentFile {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero Header

    var heroHeader: some View {
        VStack(spacing: 12) {
            // Top action row
            HStack {
                Button { app.showSettings = true } label: {
                    iconCircle("gearshape")
                }

                Spacer()

                HStack(spacing: 12) {
                    Button { showImporter = true } label: {
                        iconCircle("square.and.arrow.down")
                    }
                    Button {
                        newFileName = ""
                        showNewFileAlert = true
                    } label: {
                        iconCircle("plus")
                    }
                }
            }

            Text("SuperCollider")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)

            VStack(spacing: 10) {
                Button {
                    showTemplates = true
                } label: {
                    Text("Choose a Template")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    let file = fileManager.createFile(name: "Untitled-\(Int(Date().timeIntervalSince1970)).scd")
                    if let file = file {
                        openFile(file)
                        app.isEditing = true
                    }
                } label: {
                    Text("Start Coding")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func iconCircle(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.body)
            .foregroundColor(.primary)
            .frame(width: 36, height: 36)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Circle())
    }

    // MARK: - Actions

    @AppStorage("sc_always_edit_mode") private var alwaysEditMode = false
    @AppStorage("sc_auto_load_synthdefs") private var autoLoadSynthDefs = true

    private func openFile(_ file: SCFileManager.SCFile) {
        if let content = fileManager.loadFile(file) {
            app.lastSavedText = content
            app.codeText = content
            app.currentFile = file.path
            app.hasUnsavedChanges = false
            app.isEditing = alwaysEditMode
            app.autosave()
            // Navigate to editor (push on nav stack)
            app.showEditor = true
            if autoLoadSynthDefs {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    app.autoLoadSynthDefs()
                }
            }
        }
    }

    private func importFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let destURL = fileManager.scriptsDir.appendingPathComponent(url.lastPathComponent)
        do {
            if Foundation.FileManager.default.fileExists(atPath: destURL.path) {
                try Foundation.FileManager.default.removeItem(at: destURL)
            }
            try Foundation.FileManager.default.copyItem(at: url, to: destURL)
            fileManager.refreshFileList()
        } catch {
            app.appendPost("Import error: \(error.localizedDescription)\n")
        }
    }
}
