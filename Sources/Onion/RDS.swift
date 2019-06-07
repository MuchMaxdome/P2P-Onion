//
//  RPS.swift
//  Onion
//
//  Created by Finn Gaida on 27.05.19.
//

import Foundation
import SwiftSocket

/// All communication with the RPS module (in order to get a random next hop) goes here
struct RPS {

    /// Static local address for the fake RPS module for debugging
    private static let rpsHop = PeerHop(address: Address(version: .v4, bytes: [127, 0, 0, 1]), port: 1234, isIntermediate: false, hostkey: nil, socket: nil)

    static func getRandomHop() -> PeerHop? {
        // 1. connect to RPS
        let rpsConnection = TCPClient(address: rpsHop.address.description, port: Int32(rpsHop.port))
        switch rpsConnection.connect(timeout: tcpTimeout) {
        case .failure(let error):
            print("Couldn't connect to rps at \(rpsHop.address): \(error)")
            return nil

        case .success: break
        }

        // 2. send rps query
        let query = RPSQuery()
        guard case .success = rpsConnection.send(data: query.dataRepresentation) else {
            print("Couldn't send peer query to RPS module")
            return nil
        }
        
        guard let rpsResponse = rpsConnection.read(1024, timeout: tcpTimeout) else {
            print("Couldn't read response from RPS module")
            return nil
        }

        guard let peerPacket = PacketParser.from(Data(rpsResponse)) as? RPSPeer else { return nil }

        return PeerHop(address: peerPacket.peerAddr, port: peerPacket.peerPort, isIntermediate: true, hostkey: peerPacket.peerHostkey, socket: nil)
    }

}
