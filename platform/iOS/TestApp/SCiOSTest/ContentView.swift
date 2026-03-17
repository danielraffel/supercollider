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
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationBackground(Color(.systemBackground).opacity(0.95))
        }
        .sheet(isPresented: $app.showPost) {
            PostOverlayView()
                .environmentObject(app)
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
                .environmentObject(app)
        }
    }
}

// MARK: - File Browser Sheet

struct FileBrowserSheet: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()
    @State private var selectedTab = 0  // 0=Scripts, 1=Recordings, 2=Examples
    @State private var searchText = ""
    @State private var isSearching = false
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
        VStack(spacing: 0) {
            // Top bar: ... menu and search (like Pages)
            topBar

            // File list content
            Group {
                switch selectedTab {
                case 0: scriptsTab
                case 1: recordingsTab
                case 2: examplesTab
                default: scriptsTab
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom tab bar: Scripts / Recordings / Examples
            bottomTabBar
        }
        .onAppear {
            fileManager.refreshRecordings()
            fileManager.refreshFileList()
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
                if let file = fileManager.createFile(name: newFileName) { openFile(file) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showTemplates) {
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

    // MARK: - Top Bar (... menu + search)

    var topBar: some View {
        HStack(spacing: 10) {
            // ... menu (like Pages)
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
                    Button { } label: { Label("Name", systemImage: "textformat") }
                    Button { } label: { Label("Date", systemImage: "calendar") }
                    Button { } label: { Label("Size", systemImage: "arrow.up.arrow.down") }
                }
                Divider()
                Button { app.showSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            // Search bar (expandable like Pages)
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                    Button {
                        searchText = ""
                        withAnimation { isSearching = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Spacer()
            }

            // Search button (when not searching)
            if !isSearching {
                Button {
                    withAnimation { isSearching = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Bottom Tab Bar

    var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabButton("Scripts", icon: "doc.text", tag: 0)
            tabButton("Recordings", icon: "waveform", tag: 1)
            tabButton("Examples", icon: "book.closed", tag: 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .padding(.bottom, 16)
    }

    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == tag ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selectedTab == tag
                    ? Color.accentColor.opacity(0.1)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Tab Content

    var scriptsTab: some View {
        List {
            ForEach(filteredScripts) { file in
                Button { openFile(file) } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(file.name)
                        Spacer()
                        if file.path == app.currentFile {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
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
                emptyLabel(searchText.isEmpty ? "No scripts yet" : "No matches")
            }
        }
        .listStyle(.plain)
        .confirmationDialog("Delete script?", isPresented: Binding(
            get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } }
        ), titleVisibility: .visible) {
            if let f = fileToDelete {
                Button("Delete \(f.name)", role: .destructive) {
                    let _ = fileManager.deleteFile(f); fileToDelete = nil
                }
            }
        }
    }

    var recordingsTab: some View {
        List {
            // Show recording indicator if currently recording
            if app.isRecording {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Recording in progress...")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.red)
                    Spacer()
                    Button {
                        app.toggleRecording()
                    } label: {
                        Text("Stop")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(filteredRecordings) { rec in
                Button { selectedRecording = rec } label: {
                    HStack {
                        Image(systemName: "waveform").foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.name).foregroundColor(.primary).lineLimit(1)
                            HStack(spacing: 6) {
                                Text(rec.duration); Text(rec.size)
                            }.font(.caption2).foregroundColor(.secondary)
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
            if filteredRecordings.isEmpty && !app.isRecording {
                emptyLabel(searchText.isEmpty ? "No recordings yet" : "No matches")
            }
        }
        .listStyle(.plain)
        .confirmationDialog("Delete recording?", isPresented: Binding(
            get: { recordingToDelete != nil }, set: { if !$0 { recordingToDelete = nil } }
        ), titleVisibility: .visible) {
            if let r = recordingToDelete {
                Button("Delete \(r.name)", role: .destructive) {
                    let _ = fileManager.deleteRecording(r); recordingToDelete = nil
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
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
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

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline).foregroundColor(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 20)
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
