import SwiftUI

/// File browser for SC scripts
struct FileBrowserView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()
    @State private var showNewFileAlert = false
    @State private var newFileName = ""
    @State private var showImporter = false

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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
    }

    private func openFile(_ file: SCFileManager.SCFile) {
        if let content = fileManager.loadFile(file) {
            app.codeText = content
            app.currentFile = file.path
            app.autosave()
            // Auto-evaluate SynthDef blocks so patterns work immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                app.autoLoadSynthDefs()
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
