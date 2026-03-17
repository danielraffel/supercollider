import SwiftUI

/// File browser for SC scripts
struct FileBrowserView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var showImporter = false
    @State private var showTemplates = false
    @State private var selectedRecording: SCFileManager.Recording? = nil

    var body: some View {
        List {
            Section("Scripts") {
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
            }

            if !fileManager.recordings.isEmpty {
                Section("Recordings") {
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
                                    Text(rec.size)
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

            if !fileManager.files.filter({ $0.isExample }).isEmpty {
                Section("Examples") {
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
        }
        .onAppear {
            fileManager.refreshRecordings()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    app.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showTemplates = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                }

                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }

                Button {
                    newFileName = ""
                    showNewFileAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
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
        }
    }

    @AppStorage("sc_always_edit_mode") private var alwaysEditMode = false
    @AppStorage("sc_auto_load_synthdefs") private var autoLoadSynthDefs = true

    private func openFile(_ file: SCFileManager.SCFile) {
        if let content = fileManager.loadFile(file) {
            app.codeText = content
            app.currentFile = file.path
            app.isEditing = alwaysEditMode
            app.autosave()
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
