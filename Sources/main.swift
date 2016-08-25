
import Darwin

struct UUID {
    var storage: (UInt64, UInt64)

    var bytes: UnsafeBufferPointer<UInt8> {
        var `self` = self
        let pointer = withUnsafeMutablePointer(to: &self) { pointer in

            return unsafeBitCast(pointer, to: UnsafeMutablePointer<UInt8>.self)
        }
        return UnsafeBufferPointer(start: pointer, count: MemoryLayout<UUID>.size)
    }

    init() {
        self.storage = (0, 0)
        withUnsafeMutablePointer(to: &self) { pointer in

            let fd = open("/dev/urandom", O_RDONLY)
            defer { close(fd) }

            let bytes = unsafeBitCast(pointer, to: UnsafeMutablePointer<UInt8>.self)

            read(fd, bytes, MemoryLayout<UUID>.size)

            bytes[6] = (bytes[6] & 0x0F) | 0x40
            bytes[8] = (bytes[8] & 0x3f) | 0x80
        }
    }

    init(bytes: UnsafePointer<UInt8>) {
        self.storage = (0, 0)
        withUnsafeMutablePointer(to: &self) { pointer in
            let pointer = unsafeBitCast(self, to: UnsafeMutablePointer<UInt8>.self)
            for index in self.bytes.indices {
                pointer.advanced(by: index).pointee = bytes[index]
            }
        }
    }
}

extension UUID: CustomStringConvertible, RawRepresentable {
    /// Returns the UUID in the following format
    ///   `XXXX-XX-XX-XX-XXXXXX`
    /// where each X represents the hexadecimal
    /// representation of each byte.
    public var description: String {
        return rawValue
    }

    /// Returns the UUID in the following format
    /// `XXXX-XX-XX-XX-XXXXXX`
    /// where each X represents the hexadecimal
    /// representation of each byte.
    public var rawValue: String {
        let ranges = [0..<4, 4..<6, 6..<8, 8..<10, 10..<16]

        return ranges.map { range in
            var str = ""
            for i in range {
                str += String(bytes[i], radix: 16, uppercase: true)
            }
            return str
        }.joined(separator: "-")
    }

    /**
     Attempts to create a UUID by parsing the string.
     A correct UUID has the following format:
       `XXXX-XX-XX-XX-XXXXXX`
     where each X represents the hexadecimal
     representation of each byte.
     */
    public init?(rawValue: String) {
        guard rawValue.characters.count == 36 else {
            return nil
        }

        let bytes = UUID().bytes

        let out = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        defer { out.deallocate(capacity: 1) }

        let result: Int32 = rawValue.withCString { cString in
            let list = (0..<MemoryLayout<UUID>.size).map { bytes[$0] as CVarArg }
            return withVaList(list + [out]) { args in
                vsscanf(
                    // in
                    cString,
                    // format
                    "%2hhx%2hhx%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx-%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%n",
                    // args
                    args
                )
            }
        }

        guard result == 16 && out.pointee == 36 else {
            return nil
        }


        self.init(bytes: UnsafePointer(bytes.baseAddress!))
    }
}

extension UUID: Hashable {

    public var hashValue: Int {
        // Thanks to Ethan Jackwitz!
        // https://gist.github.com/vdka/3710efec131a403ae793a749edf34484#file-bytehashable-swift-L14-L31

        var h = 0
        for i in 0..<MemoryLayout<UUID>.size {
            h = h &+ numericCast(bytes[i])
            h = h &+ (h << 10)
            h ^= (h >> 6)
        }

        h = h &+ (h << 3)
        h ^= (h >> 11)
        h = h &+ (h << 15)

        return h
    }

    static func == (lhs: UUID, rhs: UUID) -> Bool {

        return lhs.storage == rhs.storage
    }
}

let a = UUID()
let b = UUID()
print(a) // F044A856-FF7F-00-70E5-4191000
print(b) // F044A856-FF7F-00-70E5-4191000
print(a == b) // false
// lolwut

