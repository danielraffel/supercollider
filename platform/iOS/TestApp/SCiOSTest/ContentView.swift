import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var fileSheetDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(isPresented: $app.showEditor) {
                    EditorView()
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        // File browser as non-dismissible bottom sheet
        .sheet(isPresented: .constant(!app.showEditor)) {
            FileBrowserSheet()
                .environmentObject(app)
                .presentationDetents([.medium, .large], selection: $fileSheetDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(true)
                .modifier(BackgroundInteractionModifier())
        }
        // Post Window
        .sheet(isPresented: $app.showPost) {
            PostOverlayView()
                .environmentObject(app)
        }
        // Settings
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
                .environmentObject(app)
        }
    }
}

/// File browser content for the bottom sheet
struct FileBrowserSheet: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showImporter = false
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var selectedRecording: SCFileManager.Recording? = nil
    @State private var fileToDelete: SCFileManager.SCFile? = nil
    @State private var recordingToDelete: SCFileManager.Recording? = nil
    @State private var showTemplates = false

    @AppStorage("sc_always_edit_mode") private var alwaysEditMode = false
    @AppStorage("sc_auto_load_synthdefs") private var autoLoadSynthDefs = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top action row
                HStack {
                    Spacer()

                    Menu {
                        Button { showImporter = true } label: {
                            Label("Import File", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            newFileName = ""
                            showNewFileAlert = true
                        } label: {
                            Label("New Script", systemImage: "doc.badge.plus")
                        }
                        Button { showTemplates = true } label: {
                            Label("From Template", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Menu("Sort By") {
                            Button { /* TODO */ } label: { Label("Name", systemImage: "textformat") }
                            Button { /* TODO */ } label: { Label("Date", systemImage: "calendar") }
                            Button { /* TODO */ } label: { Label("Size", systemImage: "arrow.up.arrow.down") }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Segmented tabs
                Picker("", selection: $selectedTab) {
                    Text("Scripts (\(filteredScripts.count))").tag(0)
                    Text("Recordings (\(filteredRecordings.count))").tag(1)
                    Text("Examples (\(filteredExamples.count))").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

                // Content
                switch selectedTab {
                case 0: scriptsTab
                case 1: recordingsTab
                case 2: examplesTab
                default: scriptsTab
                }
            }
            .onAppear {
                fileManager.refreshRecordings()
                fileManager.refreshFileList()
            }
            .onReceive(NotificationCenter.default.publisher(for: .scRecordingFinished)) { _ in
                fileManager.refreshRecordings()
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
                .presentationDetents([.medium])
        }
    }

    // MARK: - Filtered Lists

    private var filteredScripts: [SCFileManager.SCFile] {
        let scripts = fileManager.files.filter { !$0.isExample }
        if searchText.isEmpty { return scripts }
        return scripts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredRecordings: [SCFileManager.Recording] {
        if searchText.isEmpty { return fileManager.recordings }
        return fileManager.recordings.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredExamples: [SCFileManager.SCFile] {
        let examples = fileManager.files.filter { $0.isExample }
        if searchText.isEmpty { return examples }
        return examples.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Tabs

    var scriptsTab: some View {
        List {
            ForEach(filteredScripts) { file in
                Button { openFile(file) } label: {
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
                    Button(role: .destructive) { fileToDelete = file } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            if filteredScripts.isEmpty {
                emptyState(searchText.isEmpty ? "No scripts yet." : "No matching scripts.")
            }
        }
        .listStyle(.plain)
        .confirmationDialog("Delete this script?", isPresented: Binding(
            get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } }
        ), titleVisibility: .visible) {
            if let file = fileToDelete {
                Button("Delete \(file.name)", role: .destructive) {
                    let _ = fileManager.deleteFile(file)
                    fileToDelete = nil
                }
            }
        }
    }

    var recordingsTab: some View {
        List {
            ForEach(filteredRecordings) { rec in
                Button { selectedRecording = rec } label: {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.name).foregroundColor(.primary).lineLimit(1)
                            HStack(spacing: 6) {
                                Text(rec.duration)
                                Text(rec.size)
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle").foregroundColor(.orange)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { recordingToDelete = rec } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    ShareLink(item: rec.url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }.tint(.blue)
                }
            }
            if filteredRecordings.isEmpty {
                emptyState(searchText.isEmpty ? "No recordings yet." : "No matching recordings.")
            }
        }
        .listStyle(.plain)
        .confirmationDialog("Delete this recording?", isPresented: Binding(
            get: { recordingToDelete != nil }, set: { if !$0 { recordingToDelete = nil } }
        ), titleVisibility: .visible) {
            if let rec = recordingToDelete {
                Button("Delete \(rec.name)", role: .destructive) {
                    let _ = fileManager.deleteRecording(rec)
                    recordingToDelete = nil
                }
            }
        }
    }

    var examplesTab: some View {
        List {
            ForEach(filteredExamples) { file in
                Button { openFile(file) } label: {
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
        .listStyle(.plain)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    // MARK: - Actions

    private func openFile(_ file: SCFileManager.SCFile) {
        if let content = fileManager.loadFile(file) {
            app.lastSavedText = content
            app.codeText = content
            app.currentFile = file.path
            app.hasUnsavedChanges = false
            app.isEditing = alwaysEditMode
            app.autosave()
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

/// Enables background interaction on iOS 16.4+
struct BackgroundInteractionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackgroundInteraction(.enabled(upThrough: .medium))
        } else {
            content
        }
    }
}
