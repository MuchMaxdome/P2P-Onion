//
//  Hop.swift
//  Onion
//
//  Created by Finn Gaida on 27.05.19.
//

import Foundation
import SwiftSocket

struct Address: CustomStringConvertible {
    enum Version { case v4, v6 }
    let version: Version
    let bytes: [UInt8]

    init(version: Version, bytes: [UInt8]) {
        self.version = version
        self.bytes = bytes
    }

    init?(_ string: String) {
        // TODO:
        self.version = .v4
        self.bytes = []
    }

    var description: String {
        switch version {
        case .v4: return bytes[1..<bytes.count].reduce("\(bytes[0])", { $0 + ".\($1)" })
        case .v6: return bytes[1..<bytes.count].reduce("\(bytes[0])", { $0 + String(format: ":%02X", $1) })
        }
    }
}

protocol Hop {
    var hostkey: Hostkey? { get set }
    var socket: TCPClient?  { get set }
}

struct AnonymousHop: Hop {
    var hostkey: Hostkey?
    var socket: TCPClient?
}

struct PeerHop: Hop {
    let address: Address
    let port: UInt16
    let isIntermediate: Bool

    var hostkey: Hostkey?
    var socket: TCPClient?
}

extension PeerHop: CustomStringConvertible {
    var description: String {
        return "\(address):\(port)"
    }
}
