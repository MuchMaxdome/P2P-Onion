//
//  Config.swift
//  Onion
//
//  Created by Finn Gaida on 23.05.19.
//

import Foundation

let tcpTimeout = 10

struct Config {
    let modulePort: Int
    let apiPort: Int
    let hostname: String
    let hostkey: Hostkey
    let numberOfHops: Int
    let verbose: Bool
}
