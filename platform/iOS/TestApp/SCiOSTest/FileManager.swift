import Foundation

/// Manages SC script files within the iOS sandbox
class SCFileManager: ObservableObject {
    @Published var files: [SCFile] = []
    @Published var currentFile: SCFile?

    struct SCFile: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let path: String
        var isExample: Bool = false

        func hash(into hasher: inout Hasher) {
            hasher.combine(path)
        }

        static func == (lhs: SCFile, rhs: SCFile) -> Bool {
            lhs.path == rhs.path
        }
    }

    let documentsDir: URL
    let scriptsDir: URL

    init() {
        documentsDir = Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        scriptsDir = documentsDir.appendingPathComponent("Scripts")

        // Create Scripts directory if needed
        try? Foundation.FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

        // Create default file if none exist
        let defaultFile = scriptsDir.appendingPathComponent("scratch.scd")
        if !Foundation.FileManager.default.fileExists(atPath: defaultFile.path) {
            let defaultContent = """
            // SuperCollider for iOS
            // Press ⌘+Return to evaluate

            // Simple sine wave
            { SinOsc.ar(440, 0, 0.3) }.play;

            // FM synthesis
            (
            {
                var mod = SinOsc.ar(200, 0, 100);
                SinOsc.ar(440 + mod, 0, 0.3)
            }.play;
            )

            // Stop all sound
            CmdPeriod.run;
            """
            try? defaultContent.write(to: defaultFile, atomically: true, encoding: .utf8)
        }

        refreshFileList()
    }

    func refreshFileList() {
        var result: [SCFile] = []

        // User scripts
        if let contents = try? Foundation.FileManager.default.contentsOfDirectory(
            at: scriptsDir, includingPropertiesForKeys: nil
        ) {
            for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if url.pathExtension == "scd" || url.pathExtension == "sc" {
                    result.append(SCFile(name: url.lastPathComponent, path: url.path))
                }
            }
        }

        // Bundled examples
        if let examplesPath = Bundle.main.path(forResource: "Examples", ofType: nil) {
            if let contents = try? Foundation.FileManager.default.contentsOfDirectory(atPath: examplesPath) {
                for name in contents.sorted() where name.hasSuffix(".scd") {
                    let path = (examplesPath as NSString).appendingPathComponent(name)
                    result.append(SCFile(name: "📘 " + name, path: path, isExample: true))
                }
            }
        }

        files = result
    }

    func loadFile(_ file: SCFile) -> String? {
        try? String(contentsOfFile: file.path, encoding: .utf8)
    }

    func saveFile(_ file: SCFile, content: String) -> Bool {
        guard !file.isExample else { return false }
        do {
            try content.write(toFile: file.path, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    func createFile(name: String) -> SCFile? {
        let fileName = name.hasSuffix(".scd") ? name : name + ".scd"
        let url = scriptsDir.appendingPathComponent(fileName)
        let content = "// \(fileName)\n\n"
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            refreshFileList()
            return SCFile(name: fileName, path: url.path)
        } catch {
            return nil
        }
    }

    func deleteFile(_ file: SCFile) -> Bool {
        guard !file.isExample else { return false }
        do {
            try Foundation.FileManager.default.removeItem(atPath: file.path)
            refreshFileList()
            return true
        } catch {
            return false
        }
    }
}
