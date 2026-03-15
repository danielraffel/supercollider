import Foundation

/// Swift wrapper around the sclang C API for feasibility testing
class SclangEngine: ObservableObject {
    @Published var isInitialized = false
    @Published var isLibraryCompiled = false
    @Published var postOutput = ""
    @Published var compileTimeMs: Double = 0
    @Published var memoryUsageMB: Double = 0

    private var postCallback: SCiOSSclangPostCallback = { text, length, context in
        guard let text = text, length > 0 else { return }
        let buf = UnsafeRawBufferPointer(start: text, count: Int(length))
        let str = String(decoding: buf, as: UTF8.self)
        DispatchQueue.main.async {
            let engine = Unmanaged<SclangEngine>.fromOpaque(context!).takeUnretainedValue()
            engine.postOutput += str
            // Keep output bounded
            if engine.postOutput.count > 10000 {
                engine.postOutput = String(engine.postOutput.suffix(8000))
            }
        }
    }

    func initialize(classLibraryPath: String?) -> Bool {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        SCiOSSclangSetPostCallback(postCallback, selfPtr)

        // Set the resource directory to the parent of SCClassLibrary
        // so sclang can find SCClassLibrary inside the app bundle
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
        let startMem = getMemoryUsageMB()
        let start = CFAbsoluteTimeGetCurrent()

        let ok = SCiOSSclangCompileLibrary()

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let endMem = getMemoryUsageMB()

        compileTimeMs = elapsed
        memoryUsageMB = endMem - startMem
        isLibraryCompiled = ok

        if ok {
            postOutput += "\n=== Class library compiled in \(Int(elapsed))ms, memory delta: \(String(format: "%.1f", memoryUsageMB))MB ===\n"
        } else {
            postOutput += "\n=== Class library compilation FAILED after \(Int(elapsed))ms ===\n"
        }

        return ok
    }

    func interpret(_ code: String) -> Bool {
        guard isLibraryCompiled else {
            postOutput += "Error: library not compiled\n"
            return false
        }
        postOutput += ">>> \(code)\n"
        return SCiOSSclangInterpret(code)
    }

    func shutdown() {
        SCiOSSclangShutdown()
        isInitialized = false
        isLibraryCompiled = false
    }

    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        }
        return 0
    }
}
