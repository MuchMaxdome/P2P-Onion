//
//  ByteConversions.swift
//  Onion
//
//  Created by Maximilian Robl on 24.05.19.
//

import Foundation
import SwiftSocket

typealias Byte = UInt8

enum ByteOrder {
    case BigEndian
    case LittleEndian
}

struct ByteConversions {
    
    func unpack<T>(byteArray: [Byte], byteOrder: ByteOrder, toType: T) -> T? {
        let bytes = (byteOrder == .LittleEndian) ? byteArray : byteArray.reversed()
        
        return bytes.withUnsafeBufferPointer {
            return UnsafeRawPointer($0.baseAddress)?.load(as: T.self)
        }
    }
    
    func pack<T>(value: T, byteOrder: ByteOrder) -> [Byte] {
        let values = [value]
        var cvtValues: [Byte] = []
        
        values.withUnsafeBytes {
            cvtValues.append(contentsOf: $0)
        }
        
        return (byteOrder == .LittleEndian) ? cvtValues : cvtValues.reversed()
    }
}

protocol Packable {
    func pack(byteOrder: ByteOrder) -> [Byte]?
}

protocol Unpackable {
    func unpack<T>(byteOrder: ByteOrder, toType: T) -> T?
}

extension Int8 : Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension Int16 : Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension Int32 : Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension Int64 : Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension Int : Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension UInt16 : Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension UInt32 : Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension UInt64: Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension Double: Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension String: Packable {
    func pack(byteOrder: ByteOrder = .LittleEndian) -> [Byte]? {
        return ByteConversions().pack(value: Int.self, byteOrder: byteOrder)
    }
}

extension Array: Unpackable where Element == Byte {
    func unpack<T>(byteOrder: ByteOrder = .LittleEndian, toType: T) -> T? {
        return ByteConversions().unpack(byteArray: self, byteOrder: byteOrder, toType: toType)
    }
}

// from https://www.questarter.com/q/how-to-convert-uint16-to-uint8-in-swift-3-27_44357292.html
extension UInt16 {
    var data: Data {
        var source = self
        return Data(bytes: &source, count: MemoryLayout<UInt16>.size)
    }
}

extension Data {
    var array: [UInt8] { return Array(self) }
}
