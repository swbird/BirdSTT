import Foundation
#if canImport(zlib)
import zlib
#endif

// MARK: - Full Client Request JSON payload

struct ASRClientRequest: Encodable {
    let user: ASRUser
    let audio: ASRAudioConfig
    let request: ASRRequestConfig
}

struct ASRUser: Encodable {
    let uid: String
}

struct ASRAudioConfig: Encodable {
    let format: String
    let rate: Int
    let bits: Int
    let channel: Int
    let language: String
}

struct ASRRequestConfig: Encodable {
    let model_name: String
    let enable_itn: Bool
    let enable_punc: Bool
}

// MARK: - Server Response JSON payload

struct ASRResponse: Decodable {
    let result: ASRResultPayload?
    let audio_info: ASRAudioInfo?
}

struct ASRResultPayload: Decodable {
    let text: String
    let utterances: [ASRUtterance]?
}

struct ASRUtterance: Decodable {
    let text: String
    let definite: Bool?
    let start_time: Int?
    let end_time: Int?
}

struct ASRAudioInfo: Decodable {
    let duration: Int?
}

// MARK: - Binary Protocol

enum ASRProtocol {
    // Protocol version 1, header size = 1 (1*4 = 4 bytes)
    static let protocolVersionAndHeaderSize: UInt8 = 0x11

    // Message types (upper 4 bits of byte 1)
    static let fullClientRequest: UInt8  = 0x1
    static let audioOnlyRequest: UInt8   = 0x2
    static let fullServerResponse: UInt8 = 0x9
    static let serverError: UInt8        = 0xF

    // Message type specific flags (lower 4 bits of byte 1)
    static let noSequence: UInt8              = 0x0
    static let positiveSequence: UInt8        = 0x1
    static let lastPacketNoSequence: UInt8    = 0x2
    static let lastPacketWithSequence: UInt8  = 0x3

    // Serialization (upper 4 bits of byte 2)
    static let noSerialization: UInt8 = 0x0
    static let jsonSerialization: UInt8 = 0x1

    // Compression (lower 4 bits of byte 2)
    static let noCompression: UInt8 = 0x0
    static let gzipCompression: UInt8 = 0x1

    /// Build full client request binary message (JSON + Gzip as per docs)
    static func buildFullClientRequest(payload: Data) -> Data {
        let byte0 = protocolVersionAndHeaderSize
        let byte1 = (fullClientRequest << 4) | noSequence
        let byte2 = (jsonSerialization << 4) | gzipCompression
        let byte3: UInt8 = 0x00

        var data = Data([byte0, byte1, byte2, byte3])

        let compressed = (try? payload.gzipped()) ?? payload
        var size = UInt32(compressed.count).bigEndian
        data.append(Data(bytes: &size, count: 4))
        data.append(compressed)
        return data
    }

    /// Build audio only request binary message (Gzip compressed as per docs)
    static func buildAudioRequest(audioData: Data) -> Data {
        let byte0 = protocolVersionAndHeaderSize
        let byte1 = (audioOnlyRequest << 4) | noSequence
        let byte2 = (noSerialization << 4) | gzipCompression
        let byte3: UInt8 = 0x00

        var data = Data([byte0, byte1, byte2, byte3])

        let compressed = (try? audioData.gzipped()) ?? audioData
        var size = UInt32(compressed.count).bigEndian
        data.append(Data(bytes: &size, count: 4))
        data.append(compressed)
        return data
    }

    /// Build last audio packet (negative packet) — signals end of stream
    static func buildLastAudioRequest() -> Data {
        let byte0 = protocolVersionAndHeaderSize
        let byte1 = (audioOnlyRequest << 4) | lastPacketNoSequence
        let byte2 = (noSerialization << 4) | noCompression  // empty payload, no compression
        let byte3: UInt8 = 0x00

        var data = Data([byte0, byte1, byte2, byte3])

        // Empty payload, size = 0
        var size: UInt32 = 0
        data.append(Data(bytes: &size, count: 4))

        return data
    }

    /// Parse server response from binary data
    static func parseServerResponse(_ data: Data) -> ServerMessage? {
        guard data.count >= 4 else { return nil }

        let byte1 = data[1]
        let messageType = (byte1 >> 4) & 0x0F

        if messageType == serverError {
            return parseErrorMessage(data)
        }

        if messageType == fullServerResponse {
            return parseFullServerResponse(data)
        }

        return nil
    }

    private static func parseFullServerResponse(_ data: Data) -> ServerMessage? {
        guard data.count >= 4 else { return nil }

        let byte2 = data[2]
        let serialization = (byte2 >> 4) & 0x0F
        let compression = byte2 & 0x0F

        var offset = 4

        // Sequence number (4 bytes)
        guard data.count >= offset + 4 else { return nil }
        offset += 4

        // Payload size (4 bytes big-endian)
        guard data.count >= offset + 4 else { return nil }
        let payloadSize = Int(UInt32(bigEndian: data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }))
        offset += 4

        guard data.count >= offset + payloadSize, payloadSize > 0 else {
            return .response(ASRResponse(result: nil, audio_info: nil))
        }

        var payloadData = data.subdata(in: offset..<offset+payloadSize)

        // Decompress if gzipped
        if compression == gzipCompression {
            if let decompressed = try? payloadData.gunzipped() {
                payloadData = decompressed
            }
        }

        // Deserialize
        if serialization == jsonSerialization {
            if let response = try? JSONDecoder().decode(ASRResponse.self, from: payloadData) {
                return .response(response)
            }
        }

        return nil
    }

    private static func parseErrorMessage(_ data: Data) -> ServerMessage? {
        var offset = 4

        // Error code (4 bytes)
        guard data.count >= offset + 4 else { return .error(code: 0, message: "Unknown error") }
        let errorCode = Int(UInt32(bigEndian: data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }))
        offset += 4

        // Error message size (4 bytes)
        guard data.count >= offset + 4 else { return .error(code: errorCode, message: "Error code: \(errorCode)") }
        let msgSize = Int(UInt32(bigEndian: data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }))
        offset += 4

        // Error message
        guard data.count >= offset + msgSize else { return .error(code: errorCode, message: "Error code: \(errorCode)") }
        let message = String(data: data.subdata(in: offset..<offset+msgSize), encoding: .utf8) ?? "Error code: \(errorCode)"

        return .error(code: errorCode, message: message)
    }
}

enum ServerMessage {
    case response(ASRResponse)
    case error(code: Int, message: String)
}

// MARK: - Simple gzip decompression

extension Data {
    func gzipped() throws -> Data {
        guard !isEmpty else { return self }

        var stream = z_stream()
        stream.next_in = UnsafeMutablePointer<Bytef>(mutating: (self as NSData).bytes.bindMemory(to: Bytef.self, capacity: count))
        stream.avail_in = uInt(count)

        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw NSError(domain: "gzip", code: -1)
        }
        defer { deflateEnd(&stream) }

        var output = Data(capacity: count)
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        var status: Int32 = Z_OK
        repeat {
            buffer.withUnsafeMutableBufferPointer { bufferPtr in
                stream.next_out = bufferPtr.baseAddress
                stream.avail_out = uInt(bufferSize)
                status = deflate(&stream, Z_FINISH)
            }
            guard status == Z_OK || status == Z_STREAM_END else {
                throw NSError(domain: "gzip", code: Int(status))
            }
            let written = bufferSize - Int(stream.avail_out)
            output.append(buffer, count: written)
        } while status != Z_STREAM_END

        return output
    }

    func gunzipped() throws -> Data {
        guard count > 2 else { throw NSError(domain: "gzip", code: -1) }

        // Check gzip magic number
        guard self[0] == 0x1f && self[1] == 0x8b else { return self }

        var stream = z_stream()
        stream.next_in = UnsafeMutablePointer<Bytef>(mutating: (self as NSData).bytes.bindMemory(to: Bytef.self, capacity: count))
        stream.avail_in = uInt(count)

        guard inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw NSError(domain: "gzip", code: -1)
        }
        defer { inflateEnd(&stream) }

        var output = Data(capacity: count * 2)
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        var status: Int32 = Z_OK
        repeat {
            buffer.withUnsafeMutableBufferPointer { bufferPtr in
                stream.next_out = bufferPtr.baseAddress
                stream.avail_out = uInt(bufferSize)
                status = inflate(&stream, Z_NO_FLUSH)
            }
            guard status == Z_OK || status == Z_STREAM_END else {
                throw NSError(domain: "gzip", code: Int(status))
            }
            let written = bufferSize - Int(stream.avail_out)
            output.append(buffer, count: written)
            if status == Z_STREAM_END { break }
        } while stream.avail_out == 0

        return output
    }
}
