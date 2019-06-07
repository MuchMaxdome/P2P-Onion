//
//  Hostkey.swift
//  Onion
//
//  Created by Finn Gaida on 23.05.19.
//

import Foundation
import CommonCrypto

struct Hostkey: Equatable {
    var data: Data
    
    var count: Int {
        return data.count
    }

    let signature: Signature

    init(_ data: Data) {
        self.signature = Signature(data)
        self.data = data
    }

    init?(path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            self.init(data)
        } catch let e {
            print("Can't init hostkey with path: \(path):\n\(e)")
            return nil
        }
    }
}

struct Signature: Equatable {
    var data: Data

    var count: Int {
        return data.count
    }

    init(_ data: Data) {
        self.data = Signature.sha256(data: data)
    }

    init(raw: Data) {
        self.data = raw
    }

    /// stolen from https://stackoverflow.com/a/25391020/1642174
    private static func sha256(data : Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
}
