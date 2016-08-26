
import Darwin.C

public struct UUID {

    public var storage: (UInt64, UInt64)

    public var bytes: UnsafeBufferPointer<UInt8> {
        var `self` = self
        let pointer = withUnsafeMutablePointer(to: &self) { pointer in

            return unsafeBitCast(pointer, to: UnsafeMutablePointer<UInt8>.self)
        }
        return UnsafeBufferPointer(start: pointer, count: MemoryLayout<UUID>.size)
    }

    public init() {
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

    public init(bytes: UnsafePointer<UInt8>) {
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

    // TODO(vdka): Shift this into a static area.

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

        var uuid = UUID()

        uuid.storage = (0xBADF00D, 0xBADF00D)

        var bytes = uuid.bytes

        let out = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        defer { out.deallocate(capacity: 1) }

        func parseHex(_ string: String) -> UInt8 {

            // TODO(vdka): don't be lazy work out the indices type problem
            let utf8 = Array(string.utf8)
            // hexdecimal chars are 2 digits wide
            var inputBuffer: [Int8] = []

            // raw bytes as output
            var outputBuffer: [UInt8] = []

            //outputBuffer.reserve(capacity: 16)

            let dashIndices: Set<Int> = [8, 13, 18, 23]
            for index in utf8.indices where !dashIndices.contains(index) {

                outputBuffer.append(utf8[index])

                if outputBuffer.count == 2 {
                    var codec = UTF8()
                    var iterator = inputBuffer.makeIterator()
                    var done = false
                    while !done {
                        let result = codec.decode(&iterator)
                        switch (result) {
                        case .emptyInput: done = true
                        case .scalarValue(let scalar): outputBuffer.append(numericCast(scalar.value))
                        case .error: fatalError("HANDLE ME")
                        }
                    }
                    inputBuffer.removeAll(keepingCapacity: true)
                }
            }
        }

        let result: Int32 = rawValue.withCString { cString in

            let ranges = [0..<4, 5..<7, 8..<10, 10..<12, 12..<18]

            let indexes = [0, 1, 2, 3, _, 5, 6, _, 8, 9, _]

            let bytes = ranges.map { range in
                return UInt8(cString[range].map(String.init), radix: 16)
            }


        }

        guard result == 16 && out.pointee == 36 else {
            return nil
        }


        self.init(bytes: UnsafePointer(bytes.baseAddress!))
    }
}

extension String {
    init?<S: Sequence>(utf8: S) where S.Iterator.Element == UTF8.CodeUnit {

        var codec = UTF8()
        var str = ""
        var codeUnits = utf8.makeIterator()
        var done = false
        while !done {
            let r = codec.decode(&codeUnits)
            switch (r) {
            case .emptyInput:
                done = true
            case .scalarValue(let scalar):
                str.append(Character(scalar))
            case .error:
                return nil
            }
        }
        self = str
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
    
    public static func == (lhs: UUID, rhs: UUID) -> Bool {
        
        return lhs.storage == rhs.storage
    }
}

