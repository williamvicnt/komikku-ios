import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum SourceID {
    /// Port of `HttpSource.generateId`: first 8 bytes of MD5("<name lowercased>/<lang>/<versionId>")
    /// read big-endian, masked to a positive Int64. Producing the same IDs as Komikku keeps
    /// library backups and tracker data portable between the Android and iOS apps.
    public static func make(name: String, lang: String, versionID: Int = 1) -> Int64 {
        let key = "\(name.lowercased())/\(lang)/\(versionID)"
        let bytes = md5(Array(key.utf8))
        var result: UInt64 = 0
        for i in 0..<8 {
            result |= UInt64(bytes[i]) << UInt64(8 * (7 - i))
        }
        return Int64(bitPattern: result & UInt64(Int64.max))
    }

    private static func md5(_ input: [UInt8]) -> [UInt8] {
        #if canImport(CryptoKit)
        return Array(Insecure.MD5.hash(data: input))
        #else
        fatalError("MD5 unavailable: build on an Apple platform")
        #endif
    }
}
