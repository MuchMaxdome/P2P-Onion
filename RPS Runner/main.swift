//
//  main.swift
//  RPS Runner
//
//  Created by Finn Gaida on 27.05.19.
//

import Foundation
import SwiftSocket

func main() {
    let server = TCPServer(address: "127.0.0.1", port: 1234)
    switch server.listen() {
    case .success: print("Fake RPS module listenning on port 1234")
    case .failure(let error): return print("Can't listen on port 1234: \(error)")
    }

    while true {
        guard
            let client = server.accept(),
            let query = client.read(4),
            let packet = PacketParser.from(Data(query)),
            packet is RPSQuery
        else { continue }

        let response = RPSPeer(
            peerAddr: Address(version: .v4, bytes: [127, 0, 0, 1]),
            peerPort: 1331,
            peerHostkey: Hostkey(Data()),
            modules: [])
        switch client.send(data: response.dataRepresentation) {
        case .success: print("Sent peer \(response) to client \(client.address)")
        case .failure(let error):
            print("Couldn't send reponse to client \(client.address): \(error)")
            continue
        }
    }
}

main()
