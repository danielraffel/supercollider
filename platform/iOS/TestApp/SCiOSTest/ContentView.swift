import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var fileSheetDetent: PresentationDetent = .medium
    @State private var showSheet = true

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(isPresented: $app.showEditor) {
                    EditorView()
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        // File browser sheet — shown when not in editor
        .sheet(isPresented: $showSheet) {
            FileBrowserSheet(sheetDetent: $fileSheetDetent)
                .environmentObject(app)
                .presentationDetents([.medium, .large], selection: $fileSheetDetent)
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $app.showPost) {
            PostOverlayView()
                .environmentObject(app)
        }
        .onChange(of: app.showEditor) { _, isEditing in
            if isEditing {
                // Hide sheet instantly (no animation) when entering editor
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showSheet = false
                }
            } else {
                // Show sheet without animation when returning from editor
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showSheet = true
                }
            }
        }
    }
}

// MARK: - File Browser Sheet

struct FileBrowserSheet: View {
    @EnvironmentObject var app: AppState
    @Binding var sheetDetent: PresentationDetent
    @StateObject private var fileManager = SCFileManager()
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showImporter = false
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var selectedRecording: SCFileManager.Recording? = nil
    @State private var fileToDelete: SCFileManager.SCFile? = nil
    @State private var recordingToDelete: SCFileManager.Recording? = nil
    @State private var sortBy = "Date"
    @State private var viewMode = "List"  // "List" or "Icons"
    @Namespace private var glassNS

    @AppStorage("sc_always_edit_mode") private var alwaysEditMode = false
    @AppStorage("sc_auto_load_synthdefs") private var autoLoadSynthDefs = true

    private var isExpanded: Bool { sheetDetent == .large }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                switch selectedTab {
                case 0: scriptsTab
                case 1: recordingsTab
                case 2: examplesTab
                default: scriptsTab
                }
            }
            .frame(maxHeight: .infinity)

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
        .fullScreenCover(isPresented: $app.showTemplates) {
            TemplateCoverView()
                .environmentObject(app)
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
                .environmentObject(app)
        }
        .sheet(item: $selectedRecording) { rec in
            RecordingPlayerView(recording: rec)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack(spacing: 8) {
            Spacer()

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
                .padding(10)
                .glassEffect(.regular, in: .capsule)
                .transition(.opacity)
            } else {
                // All icons on one line: [+] [...] in one pill, [search] separate
                HStack(spacing: 8) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 0) {
                            if isExpanded {
                                Button {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "MMdd-HHmm"
                                    let name = "sketch-\(formatter.string(from: Date())).scd"
                                    if let file = fileManager.createFile(name: name) {
                                        openFile(file)
                                        app.isEditing = true
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.body.weight(.medium))
                                        .frame(width: 40, height: 36)
                                }
                            }

                            Menu {
                                Button { showImporter = true } label: {
                                    Label("Import File", systemImage: "square.and.arrow.down")
                                }
                                Button { withAnimation { app.showTemplates = true } } label: {
                                    Label("From Template", systemImage: "doc.on.doc")
                                }
                                Button {
                                    newFileName = ""
                                    showNewFileAlert = true
                                } label: {
                                    Label("New Script", systemImage: "doc.badge.plus")
                                }
                                Divider()
                                Picker("View", selection: $viewMode) {
                                    Label("Icons", systemImage: "square.grid.2x2").tag("Icons")
                                    Label("List", systemImage: "list.bullet").tag("List")
                                }
                                Divider()
                                Picker("Sort By", selection: $sortBy) {
                                    Text("Name").tag("Name")
                                    Text("Kind").tag("Kind")
                                    Text("Date").tag("Date")
                                    Text("Size").tag("Size")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.body.weight(.medium))
                                    .frame(width: 40, height: 36)
                            }
                        }
                        .foregroundColor(.primary)
                        .glassEffect(.regular, in: .capsule)
                    }

                    Button {
                        withAnimation { isSearching = true }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 36)
                    }
                    .glassEffect(.regular, in: .capsule)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Bottom Tab Bar

    var bottomTabBar: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                tabButton("Scripts", icon: "doc.text", tag: 0)
                tabButton("Recordings", icon: "waveform", tag: 1)
                tabButton("Examples", icon: "book.closed", tag: 2)
            }
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .padding(.bottom, 8)
    }

    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tag }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.body)
                Text(title).font(.caption2)
            }
            .foregroundColor(selectedTab == tag ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Tab Content

    var scriptsTab: some View {
        Group {
            if viewMode == "Icons" {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(filteredScripts) { file in
                            Button { openFile(file) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.accentColor)
                                        .frame(height: 60)
                                    Text(file.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(
                                    file.path == app.currentFile
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear
                                )
                                .cornerRadius(10)
                            }
                            .contextMenu {
                                Button(role: .destructive) { fileToDelete = file } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            } else {
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
            }
        }
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
        Group {
            if viewMode == "Icons" {
                ScrollView {
                    if app.isRecording {
                        recordingBanner
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(filteredRecordings) { rec in
                            Button { selectedRecording = rec } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "waveform.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.red)
                                        .frame(height: 60)
                                    Text(rec.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    Text(rec.duration)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .cornerRadius(10)
                            }
                            .contextMenu {
                                Button(role: .destructive) { recordingToDelete = rec } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                ShareLink(item: rec.url) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            } else {
                List {
                    if app.isRecording {
                        recordingBanner
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
            }
        }
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

    var recordingBanner: some View {
        HStack {
            Circle().fill(Color.red).frame(width: 8, height: 8)
            Text("Recording in progress...")
                .font(.subheadline.weight(.medium)).foregroundColor(.red)
            Spacer()
            Button { app.toggleRecording() } label: {
                Text("Stop").font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.red).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    var examplesTab: some View {
        Group {
            if viewMode == "Icons" {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(filteredExamples) { file in
                            Button { openFile(file) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.orange)
                                        .frame(height: 60)
                                    Text(file.name.replacingOccurrences(of: "📘 ", with: ""))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(
                                    file.path == app.currentFile
                                        ? Color.accentColor.opacity(0.1) : Color.clear
                                )
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            } else {
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
        }
    }

    // MARK: - Helpers

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
        Text(text).font(.subheadline).foregroundColor(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 20)
    }

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
