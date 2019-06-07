//
//  Tunnel.swift
//  Onion
//
//  Created by Finn Gaida on 03.06.19.
//

import Foundation

/// Abstraction of an onion route
struct Tunnel {
    enum State {
        case building, active, tearingDown, inactive
    }

    var state: State = .inactive

    let id: UInt16
    var nextHop: Hop?
    var previousHop: Hop?

    init(id: UInt16? = nil) {
        self.id = id ?? UInt16(arc4random()) % UInt16.max
    }
}
