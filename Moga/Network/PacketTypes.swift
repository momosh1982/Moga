import Foundation

// MARK: - Packet type identifiers (8-byte header: type UInt32 + length UInt32)

enum PacketType: UInt32 {
    case connect    = 0x01
    case disconnect = 0x02
    case config     = 0x03
    case hardware   = 0x04
    case pin        = 0x05
    case light      = 0x06
    case motor      = 0x07
    case camera     = 0x08
    case params     = 0x09
    case photo      = 0x0A
    case capture    = 0x0B
    case data       = 0x0C
    case chunk      = 0x0D
    case video      = 0x0E
    case stream     = 0x0F
    case metadata   = 0x10
    case command    = 0x11
    case info       = 0x12
    case status     = 0x13
}

// MARK: - Packet header

struct PacketHeader {
    let type: PacketType
    let length: UInt32

    static let size = 8

    func encode() -> Data {
        var data = Data(count: 8)
        data.writeUInt32(type.rawValue, at: 0)
        data.writeUInt32(length, at: 4)
        return data
    }

    static func decode(from data: Data) -> PacketHeader? {
        guard data.count >= size,
              let type = PacketType(rawValue: data.readUInt32(at: 0)) else { return nil }
        return PacketHeader(type: type, length: data.readUInt32(at: 4))
    }
}

// MARK: - Individual packet payloads

struct ConnectPacket {
    let protocolVersion: UInt8  // currently 1
    let enableLogging: Bool

    func encode() -> Data {
        var d = Data(count: 2)
        d[0] = protocolVersion
        d[1] = enableLogging ? 1 : 0
        return d
    }
}

struct DisconnectPacket {
    func encode() -> Data { Data() }
}

struct LightPacket {
    let on: Bool
    func encode() -> Data { Data([on ? 1 : 0]) }
}

struct MotorPacket {
    enum MotorID: UInt8 { case rotor = 0, turntable = 1 }
    enum Mode: UInt8 { case relative = 0, absolute = 1 }

    let motor: MotorID
    let mode: Mode
    let angle: Float   // degrees
    let zeroPosition: Bool

    func encode() -> Data {
        var d = Data(count: 7)
        d[0] = motor.rawValue
        d[1] = mode.rawValue
        d.writeFloat(angle, at: 2)
        d[6] = zeroPosition ? 1 : 0
        return d
    }
}

struct PhotoPacket {
    let focusDiopters: Float   // focus distance in diopters
    let rotorAngle: Float
    let turntableAngle: Float
    let delayMs: UInt16
    let stackIndex: UInt16

    func encode() -> Data {
        var d = Data(count: 18)
        d.writeFloat(focusDiopters, at: 0)
        d.writeFloat(rotorAngle, at: 4)
        d.writeFloat(turntableAngle, at: 8)
        d.writeUInt16(delayMs, at: 12)
        d.writeUInt16(stackIndex, at: 14)
        return d
    }
}

struct CapturePacket {
    let positionIndex: UInt32
    func encode() -> Data {
        var d = Data(count: 4)
        d.writeUInt32(positionIndex, at: 0)
        return d
    }
}

struct ChunkPacket {
    let positionIndex: UInt32
    let stackIndex: UInt16
    let chunkIndex: UInt16
    let totalChunks: UInt16
    let payload: Data

    static func decode(from data: Data) -> ChunkPacket? {
        guard data.count >= 10 else { return nil }
        return ChunkPacket(
            positionIndex: data.readUInt32(at: 0),
            stackIndex:    data.readUInt16(at: 4),
            chunkIndex:    data.readUInt16(at: 6),
            totalChunks:   data.readUInt16(at: 8),
            payload:       data.subdata(in: 10..<data.count)
        )
    }
}

struct StatusPacket {
    let isScanning: Bool
    let isConnected: Bool

    static func decode(from data: Data) -> StatusPacket? {
        guard data.count >= 2 else { return nil }
        return StatusPacket(isScanning: data[0] == 1, isConnected: data[1] == 1)
    }
}

// MARK: - Data helpers (little-endian)

extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { copyBytes(to: $0, from: offset..<offset+4) }
        return UInt32(littleEndian: value)
    }

    func readUInt16(at offset: Int) -> UInt16 {
        var value: UInt16 = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { copyBytes(to: $0, from: offset..<offset+2) }
        return UInt16(littleEndian: value)
    }

    func readFloat(at offset: Int) -> Float {
        let bits = readUInt32(at: offset)
        return Float(bitPattern: bits)
    }

    mutating func writeUInt32(_ value: UInt32, at offset: Int) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { bytes in
            replaceSubrange(offset..<offset+4, with: bytes)
        }
    }

    mutating func writeUInt16(_ value: UInt16, at offset: Int) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { bytes in
            replaceSubrange(offset..<offset+2, with: bytes)
        }
    }

    mutating func writeFloat(_ value: Float, at offset: Int) {
        writeUInt32(value.bitPattern, at: offset)
    }
}
