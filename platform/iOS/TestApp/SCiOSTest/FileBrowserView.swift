import SwiftUI

/// File browser for SC scripts
struct FileBrowserView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var fileManager = SCFileManager()
    @State private var showNewFileAlert = false
    @State private var newFileName = ""

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
                            Text(file.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Files")
        .toolbar {
            Button {
                newFileName = ""
                showNewFileAlert = true
            } label: {
                Image(systemName: "plus")
            }
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
        }
    }
}
