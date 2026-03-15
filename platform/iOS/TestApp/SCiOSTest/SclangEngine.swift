import Foundation

/// Swift wrapper around the sclang C API
class SclangEngine: ObservableObject {
    @Published var isInitialized = false
    @Published var isLibraryCompiled = false
    @Published var postOutput = ""

    /// External post callback for routing output to AppState
    var postCallback: ((String) -> Void)?

    private var cPostCallback: SCiOSSclangPostCallback = { text, length, context in
        guard let text = text, length > 0 else { return }
        let buf = UnsafeRawBufferPointer(start: text, count: Int(length))
        let str = String(decoding: buf, as: UTF8.self)
        let engine = Unmanaged<SclangEngine>.fromOpaque(context!).takeUnretainedValue()
        // Route to external callback if set
        engine.postCallback?(str)
        // Also store locally
        DispatchQueue.main.async {
            engine.postOutput += str
            if engine.postOutput.count > 50000 {
                engine.postOutput = String(engine.postOutput.suffix(40000))
            }
        }
    }

    func initialize(classLibraryPath: String?) -> Bool {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        SCiOSSclangSetPostCallback(cPostCallback, selfPtr)

        if let path = classLibraryPath {
            let parentDir = (path as NSString).deletingLastPathComponent
            SCiOSSclangSetResourceDir(parentDir)
        }

        var config = SCiOSSclangConfigDefault()
        var errorBuf = [CChar](repeating: 0, count: 256)

        let ok = SCiOSSclangInit(&config, &errorBuf, 256)
        if !ok {
            let error = String(cString: errorBuf)
            postOutput += "Init error: \(error)\n"
        }
        isInitialized = ok
        return ok
    }

    func compileLibrary() -> Bool {
        let ok = SCiOSSclangCompileLibrary()
        isLibraryCompiled = ok
        return ok
    }

    func interpret(_ code: String) -> Bool {
        guard isLibraryCompiled else { return false }
        return SCiOSSclangInterpret(code)
    }

    func shutdown() {
        SCiOSSclangShutdown()
        isInitialized = false
        isLibraryCompiled = false
    }
}
