import Foundation

/// Minimal OSC message builder for SuperCollider server commands
struct OSCMessage {
    /// Build an OSC message with address and arguments
    static func build(_ address: String, _ args: [Any] = []) -> Data {
        var data = Data()

        // Address string (null-terminated, padded to 4-byte boundary)
        data.append(oscString(address))

        // Type tag string
        var typeTags = ","
        for arg in args {
            switch arg {
            case is Int32: typeTags += "i"
            case is Int: typeTags += "i"
            case is Float: typeTags += "f"
            case is Double: typeTags += "f"
            case is String: typeTags += "s"
            case is Data: typeTags += "b"
            default: break
            }
        }
        data.append(oscString(typeTags))

        // Arguments
        for arg in args {
            switch arg {
            case let v as Int32:
                data.append(oscInt32(v))
            case let v as Int:
                data.append(oscInt32(Int32(v)))
            case let v as Float:
                data.append(oscFloat(v))
            case let v as Double:
                data.append(oscFloat(Float(v)))
            case let v as String:
                data.append(oscString(v))
            case let v as Data:
                data.append(oscBlob(v))
            default:
                break
            }
        }

        return data
    }

    /// Build an OSC bundle with timetag and messages
    static func bundle(timetag: UInt64 = 1, messages: [Data]) -> Data {
        var data = Data()
        data.append(oscString("#bundle"))
        data.append(oscUInt64(timetag))
        for msg in messages {
            data.append(oscInt32(Int32(msg.count)))
            data.append(msg)
        }
        return data
    }

    // MARK: - Private helpers

    private static func oscString(_ s: String) -> Data {
        var data = s.data(using: .utf8)!
        data.append(0) // null terminator
        while data.count % 4 != 0 { data.append(0) } // pad to 4 bytes
        return data
    }

    private static func oscInt32(_ v: Int32) -> Data {
        var big = v.bigEndian
        return Data(bytes: &big, count: 4)
    }

    private static func oscUInt64(_ v: UInt64) -> Data {
        var big = v.bigEndian
        return Data(bytes: &big, count: 8)
    }

    private static func oscFloat(_ v: Float) -> Data {
        var big = v.bitPattern.bigEndian
        return Data(bytes: &big, count: 4)
    }

    private static func oscBlob(_ blob: Data) -> Data {
        var data = Data()
        var size = Int32(blob.count).bigEndian
        data.append(Data(bytes: &size, count: 4))
        data.append(blob)
        while data.count % 4 != 0 { data.append(0) }
        return data
    }
}

// MARK: - SuperCollider OSC Commands

extension OSCMessage {
    /// /status - query server status
    static var status: Data { build("/status") }

    /// /s_new - create a new synth
    /// - Parameters:
    ///   - defName: SynthDef name
    ///   - nodeID: node ID (-1 for auto)
    ///   - addAction: 0=head, 1=tail, 2=before, 3=after
    ///   - targetID: target group/node ID
    ///   - args: pairs of [controlName, value, ...]
    static func sNew(_ defName: String, nodeID: Int32 = -1, addAction: Int32 = 0,
                     targetID: Int32 = 0, args: [Any] = []) -> Data {
        var allArgs: [Any] = [defName, nodeID, addAction, targetID]
        allArgs.append(contentsOf: args)
        return build("/s_new", allArgs)
    }

    /// /n_free - free a node
    static func nFree(_ nodeID: Int32) -> Data {
        build("/n_free", [nodeID])
    }

    /// /n_set - set a node's control value
    static func nSet(_ nodeID: Int32, _ controlName: String, _ value: Float) -> Data {
        build("/n_set", [nodeID, controlName, value])
    }

    /// /g_new - create a new group
    static func gNew(_ groupID: Int32, addAction: Int32 = 0, targetID: Int32 = 0) -> Data {
        build("/g_new", [groupID, addAction, targetID])
    }

    /// /d_recv - receive a SynthDef
    static func dRecv(_ synthDefData: Data) -> Data {
        build("/d_recv", [synthDefData])
    }

    /// /b_alloc - allocate a buffer
    static func bAlloc(_ bufNum: Int32, numFrames: Int32, numChannels: Int32 = 1) -> Data {
        build("/b_alloc", [bufNum, numFrames, numChannels])
    }

    /// /b_free - free a buffer
    static func bFree(_ bufNum: Int32) -> Data {
        build("/b_free", [bufNum])
    }

    /// /quit - shut down the server
    static var quit: Data { build("/quit") }

    /// /notify - register for server notifications
    static func notify(_ flag: Int32 = 1) -> Data {
        build("/notify", [flag])
    }
}
