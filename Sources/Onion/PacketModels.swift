//
//  PacketModels.swift
//  Onion
//
//  Created by Finn Gaida on 23.05.19.
//

import Foundation

enum PacketType: UInt16 {
    case ONION_TUNNEL_BUILD     = 560
    case ONION_TUNNEL_READY     = 561
    case ONION_TUNNEL_INCOMING  = 562
    case ONION_TUNNEL_DESTROY   = 563
    case ONION_TUNNEL_DATA      = 564
    case ONION_ERROR            = 565
    case ONION_COVER            = 566

    case RPS_QUERY              = 540
    case RPS_PEER               = 541

    case API_PING               = 9000
    case API_PING_RESPONSE      = 9001
    case API_NEXT_HOP_QUERY     = 9002
    case API_NEXT_HOP_RESPONSE  = 9003
    case API_FINAL_HOP_QUERY    = 9004
    case API_DATA               = 9005
}

protocol Packet {
    var size: UInt16 { get }
    var type: PacketType { get }
    init?(_ data: Data)
    var dataRepresentation: Data { get }
}

struct PacketParser {

    /// Check the packet type flag to determine the type of this generic package and delegate to the corresponding struct
    ///
    /// - Returns: Struct implementing the packet type or nil if the type is unknown
    static func from(_ data: Data) -> Packet? {
        let rawType = data[2...3].withUnsafeBytes({ $0.load(as: UInt16.self) })
        guard let type = PacketType(rawValue: rawType) else {
            print("Unknown packet type \(rawType)")
            return nil
        }

        switch type {
        case .ONION_TUNNEL_BUILD:       return TunnelBuild(data)
        case .ONION_TUNNEL_READY:       return TunnelReady(data)
        case .ONION_TUNNEL_INCOMING:    return TunnelIncoming(data)
        case .ONION_TUNNEL_DESTROY:     return TunnelDestroy(data)
        case .ONION_TUNNEL_DATA:        return TunnelData(data)
        case .ONION_ERROR:              return TunnelError(data)
        case .ONION_COVER:              return TunnelCover(data)

        case .RPS_QUERY:                return RPSQuery(data)
        case .RPS_PEER:                 return RPSPeer(data)

        case .API_PING:                 return APIPing(data)
        case .API_PING_RESPONSE:        return APIPingResponse(data)
        case .API_NEXT_HOP_QUERY:       return APINextHopQuery(data)
        case .API_NEXT_HOP_RESPONSE:    return APINextHopResponse(data)
        case .API_FINAL_HOP_QUERY:      return APIFinalHopQuery(data)
        case .API_DATA:                 return APIData(data)
        }
    }
}

// MARK: - Onion packets

/*
 * This message is to be used by the CM/UI module to request the Onion module to build
 * a tunnel to the given destination in the next period. The message is identiﬁed by
 * ONION TUNNEL BUILD message type. The version of the network address is speciﬁed by the ﬂag V;
 * it is set to 0 for IPv4, and 1 for IPv6. See Figure 19 for the message format.
 */
struct TunnelBuild: Packet {
    let size: UInt16
    let type: PacketType = .ONION_TUNNEL_BUILD

    let destPort: UInt16
    let destAddr: Address
    let destHostkey: Hostkey

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })

        let isIPv4 = (data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) }) & 1) == 0
        self.destPort = data[6...7].withUnsafeBytes({ $0.load(as: UInt16.self) })

        if isIPv4 {
            let addrRaw = data[8...11].withUnsafeBytes({ Array($0).map { UInt8($0) } })
            self.destAddr = Address(version: .v4, bytes: addrRaw)
            self.destHostkey = Hostkey(data.subdata(in: 12..<data.count))
        } else {
            let addrRaw = data[8...23].withUnsafeBytes({ Array($0).map { UInt8($0) } })
            self.destAddr = Address(version: .v6, bytes: addrRaw)
            self.destHostkey = Hostkey(data.subdata(in: 24..<data.count))
        }
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: (destAddr.version == .v4 ? UInt16(0) : UInt16(1)).pack()!)
        array.append(contentsOf: destPort.pack()!)
        array.append(contentsOf: destAddr.bytes)
//        array.append(contentsOf: destHostkey)
        return Data(array)
    }
}

/*
 * This message is identiﬁed by the message type ONION TUNNEL READY and is sent by the Onion module
 * when the requested tunnel is built. The recipient of this message is allowed to send data in this
 * tunnel after receiving this message. It contains the identity of the destination peer and a
 * tunnel ID which is assigned by the Onion to uniquely identify diﬀerent tunnels.
 * See Figure 20 for message format.
 */
struct TunnelReady: Packet {
    let size: UInt16
    let type: PacketType = .ONION_TUNNEL_READY

    let tunnelID: UInt32
    let destHostkey: Hostkey

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })

        self.tunnelID = data[4...7].withUnsafeBytes({ $0.load(as: UInt32.self) })
        self.destHostkey = Hostkey(data.subdata(in: 8..<data.count))
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
//        array.append(destHostkey)
        return Data(array)
    }
}

/*
 * This message is sent by the Onion on all of its API connections to signal a new incoming tunnel connection.
 * The new tunnel will be identiﬁed by the given tunnel ID. The format of this message is show in Figure 21.
 *
 * No response is solicited by Onion for this message. When undesired, the tunnel could be destroyed
 * by sending ONION TUNNEL DESTROY message.
 *
 * Incoming data on this tunnel is duplicated and sent to all API connections which have not yet sent
 * an ONION TUNNEL DESTROY for this tunnel ID. An incoming tunnel is to be destroyed only if all
 * the API connections sent a ONION TUNNEL DESTROY for it.
 */
struct TunnelIncoming: Packet {
    let size: UInt16
    let type: PacketType = .ONION_TUNNEL_INCOMING

    let tunnelID: UInt32

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...7].withUnsafeBytes({ $0.load(as: UInt32.self) })
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        return Data(array)
    }
}

/*
 * This message is used to instruct the Onion module that a tunnel it created is no longer in use and it can now be destroyed.
 * The message is identiﬁed by the message type ONION TUNNEL DESTROY. The tunnel ID should be valid, i.e.,
 * it should have been sent by the Onion in a previous ONION TUNNEL READY or ONION TUNNEL INCOMING message.
 */
struct TunnelDestroy: Packet {
    let size: UInt16
    let type: PacketType = .ONION_TUNNEL_DESTROY

    let tunnelID: UInt32

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...7].withUnsafeBytes({ $0.load(as: UInt32.self) })
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        return Data(array)
    }
}

/*
 * This message is used to ask Onion to forward data on a tunnel. It is also used by Onion to send data from an incoming tunnel.
 * The tunnel ID in the message corresponds to the tunnel which is used to forwarding the data;
 * for incoming data it is the tunnel on which the data is received.
 *
 * For outgoing data Onion should make a best eﬀort to forward the given data. However, no guarantee is required:
 * the data could be lost and/or delivered out of order.
 */
struct TunnelData: Packet {
    let size: UInt16
    let type: PacketType = .ONION_TUNNEL_DATA

    let tunnelID: UInt32
    let data: Data

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...7].withUnsafeBytes({ $0.load(as: UInt32.self) })
        self.data = data.subdata(in: 8..<data.count)
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        array.append(contentsOf: data)
        return Data(array)
    }
}

/*
 * This message is sent by the Onion to signal an error condition which has stemmed from servicing an earlier request.
 * The message will contain the tunnel ID to signal the failure of an established tunnel.
 * The error condition is not be mistaken with API violations. Error conditions trigger upon correct usage of API.
 * API violations are to be handled by terminating the connection to the misbehaving client.
 */
struct TunnelError: Packet {
    let size: UInt16
    let type: PacketType = .ONION_ERROR

    let requestType: PacketType
    let tunnelID: UInt32

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        guard let requestType = PacketType(rawValue: data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })) else { return nil }
        self.requestType = requestType
        self.tunnelID = data[8...11].withUnsafeBytes({ $0.load(as: UInt32.self) })
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: requestType.rawValue.pack()!)
        array.append(0)
        array.append(contentsOf: tunnelID.pack()!)
        return Data(array)
    }
}

/*
 * This message identiﬁes cover traﬃc which is sent to a random destination by the Onion module.
 * The CM/UI module uses this message to fabricate cover traﬃc mimicking the characteristics of real traﬃc.
 * Upon receiving this message, the Onion module should send given amount of random bytes on the
 * tunnel established to a random destination in a round.
 * It is illegal to send this message when a tunnel is established and Onion has replied with ONION TUNNEL READY.
 */
struct TunnelCover: Packet {
    let size: UInt16
    let type: PacketType = .ONION_COVER

    let coverSize: UInt16

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.coverSize = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: coverSize.pack()!)
        array.append(0)
        return Data(array)
    }
}

/*
 * This message is used to ask RPS to reply with a random peer.
 * This message is short and consists only the header. The format is shown in Figure 17.
 */
struct RPSQuery: Packet {
    let size: UInt16
    let type: PacketType = .RPS_QUERY

    init() {
        self.size = 4
    }

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        return Data(array)
    }
}

// MARK: - RPS packets

/*
 * This message is sent by the RPS module as a response to the RPS QUERY message. The format is shown in Figure 18.
 * It contains the peer identity and the network address of a peer which is selected by RPS at random.
 * The version of the network address is speciﬁed by the ﬂag V; it is set to 0 for IPv4, and 1 for IPv6.
 * In addition to this it also contains a portmap for the P2P listen ports of the various modules on the random peer.
 * The RPS module of a peer should get the listen port addresses from its conﬁguration.
 *
 * The ﬁeld #portmap contains the total number of portmap records. Each port record is of 4 bytes long;
 * the ﬁrst 2 bytes identiﬁes the module (shown in the ﬁgure as App), the next 2 bytes contain the listen
 * port number of that module.
 *
 * RPS should sample random peers from the currently online peers. Therefore the peer sent in this
 * message is very likely to be online, but no strict guarantee could be made about its presence.
 */
struct RPSPeer: Packet {
    struct ModuleAPI {
        enum ModuleType: UInt16 {
            case DHT = 650
            case Gossip = 500
            case NSE = 520
            case Onion = 560
        }

        let moduleType: ModuleType
        let port: UInt16
    }

    let size: UInt16
    let type: PacketType = .RPS_PEER

    let peerAddr: Address
    let peerPort: UInt16
    let peerHostkey: Hostkey

    let modules: [ModuleAPI]

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })

        self.peerPort = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
        let numModules = Int(data[6...6].withUnsafeBytes({ $0.load(as: UInt8.self) }))
        let isIPv4 = (data[7...7].withUnsafeBytes({ $0.load(as: UInt8.self) }) & 1) == 0

        // go over modules and parse each one into the array
        var modules = [ModuleAPI]()
        for i in 0..<numModules {
            let rawType = data[(8+i)...(9+i)].withUnsafeBytes({ $0.load(as: UInt16.self) })
            guard let type = RPSPeer.ModuleAPI.ModuleType(rawValue: rawType) else {
                print("Can't parse API type \(rawType)")
                continue
            }

            let apiPort = data[(10+i)...(11+i)].withUnsafeBytes({ $0.load(as: UInt16.self) })
            modules.append(ModuleAPI(moduleType: type, port: apiPort))
        }
        self.modules = modules

        // parse IP
        let ipAddrOffset = 8 + 4 * numModules
        if isIPv4 {
            let addrRaw = data[(ipAddrOffset)...(ipAddrOffset+3)].withUnsafeBytes({ Array($0).map { UInt8($0) } })
            self.peerAddr = Address(version: .v4, bytes: addrRaw)
            self.peerHostkey = Hostkey(data.subdata(in: (ipAddrOffset+4)..<data.count))
        } else {
            let addrRaw = data[(ipAddrOffset)...(ipAddrOffset+15)].withUnsafeBytes({ Array($0).map { UInt8($0) } })
            self.peerAddr = Address(version: .v6, bytes: addrRaw)
            self.peerHostkey = Hostkey(data.subdata(in: (ipAddrOffset+16)..<data.count))
        }
    }

    init(peerAddr: Address, peerPort: UInt16, peerHostkey: Hostkey, modules: [ModuleAPI]) {
        self.peerAddr = peerAddr
        self.peerPort = peerPort
        self.peerHostkey = peerHostkey
        self.modules = modules
        self.size = UInt16(8 + 4 * modules.count + (peerAddr.version == .v4 ? 4 : 16) + peerHostkey.count)
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        for element in [size, type.rawValue, peerPort, UInt16(UInt8(modules.count) << 8 + (peerAddr.version == .v4 ? 0 : 1))] {
            array.append(contentsOf: element.littleEndian.pack()!)
        }
        for module in modules {
            array.append(contentsOf: module.moduleType.rawValue.pack()!)
            array.append(contentsOf: module.port.littleEndian.pack()!)
        }
        array.append(contentsOf: peerAddr.bytes)
        return Data(array)
    }
}

// MARK: - API Packets
protocol APIPacket: Packet {
    var size: UInt16 { get }
    var type: PacketType { get }
    var tunnelID: UInt16 { get }
}

/// Sent by any intermediate hop to get to know it's next hop
struct APIPing: APIPacket {
    let size: UInt16
    let type: PacketType = .API_PING

    let tunnelID: UInt16
    let hostkey: Hostkey

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.hostkey = Hostkey(data.subdata(in: 6..<data.count))
    }

    init(tunnelID: UInt16, hostkey: Hostkey) {
        self.size = UInt16(6 + hostkey.count)
        self.tunnelID = tunnelID
        self.hostkey = hostkey
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        var data = Data(array)
        data.append(hostkey.data)
        return data
    }
}

/// Sent back if a PING packet is received to identify the hop
struct APIPingResponse: APIPacket {
    let size: UInt16
    let type: PacketType = .API_PING_RESPONSE

    let tunnelID: UInt16
    let hostkey: Hostkey

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.hostkey = Hostkey(data.subdata(in: 6..<data.count))
    }

    init(tunnelID: UInt16, hostkey: Hostkey) {
        self.size = UInt16(6 + hostkey.count)
        self.tunnelID = tunnelID
        self.hostkey = hostkey
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        var data = Data(array)
        data.append(hostkey.data)
        return data
    }
}

/// Commands the receiving hop to try and connect to a new random (RPS) hop
struct APINextHopQuery: APIPacket {
    let size: UInt16
    let type: PacketType = .API_NEXT_HOP_QUERY

    let tunnelID: UInt16

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
    }

    init(tunnelID: UInt16) {
        self.size = 6
        self.tunnelID = tunnelID
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        return Data(array)
    }
}

/// Sent back to the initiator once the hop has successfully connected to a new hop
struct APINextHopResponse: APIPacket {
    let size: UInt16
    let type: PacketType = .API_NEXT_HOP_RESPONSE

    let tunnelID: UInt16
    let nextHopHostkey: Hostkey

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.nextHopHostkey = Hostkey(data.subdata(in: 8..<data.count))
    }

    init(tunnelID: UInt16, nextHopHostkey: Hostkey) {
        self.size = UInt16(6 + nextHopHostkey.count)
        self.tunnelID = tunnelID
        self.nextHopHostkey = nextHopHostkey
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        var data = Data(array)
        data.append(nextHopHostkey.data)
        return data
    }
}

/// Sent to the last intermediate hop in the tunnel to instruct it to connect to the final hop
struct APIFinalHopQuery: APIPacket {
    let size: UInt16
    let type: PacketType = .API_FINAL_HOP_QUERY

    let tunnelID: UInt16
    let destPort: UInt16
    let destAddr: Address
    let destHostkey: Hostkey

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.destPort = data[6...7].withUnsafeBytes({ $0.load(as: UInt16.self) })
        let isIPv4 = (data[8...9].withUnsafeBytes({ $0.load(as: UInt16.self) }) & 1 == 0)

        if isIPv4 {
            let addrRaw = data[10...13].withUnsafeBytes({ Array($0).map { UInt8($0) } })
            self.destAddr = Address(version: .v4, bytes: addrRaw)
            self.destHostkey = Hostkey(data.subdata(in: 12..<data.count))
        } else {
            let addrRaw = data[10...25].withUnsafeBytes({ Array($0).map { UInt8($0) } })
            self.destAddr = Address(version: .v6, bytes: addrRaw)
            self.destHostkey = Hostkey(data.subdata(in: 24..<data.count))
        }
    }

    init(tunnelID: UInt16, destPort: UInt16, destAddr: Address, destHostkey: Hostkey) {
        self.size = UInt16(8 + (destAddr.version == .v4 ? 4 : 24) + destHostkey.count)
        self.tunnelID = tunnelID
        self.destPort = destPort
        self.destAddr = destAddr
        self.destHostkey = destHostkey
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        array.append(contentsOf: destPort.pack()!)
        array.append(contentsOf: destAddr.bytes)
        var data = Data(array)
        data.append(destHostkey.data)
        return data
    }
}

/// Arbitrary data sent over the onion tunnel
struct APIData: APIPacket {
    let size: UInt16
    let type: PacketType = .API_DATA

    let tunnelID: UInt16
    let hopID: Signature

    // This should be encrypted with the destinations' pub key
    let data: Data

    init?(_ data: Data) {
        self.size = data[0...1].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.tunnelID = data[4...5].withUnsafeBytes({ $0.load(as: UInt16.self) })
        self.hopID = Signature(raw: data.subdata(in: 6..<8))

        self.data = data.subdata(in: 8..<data.count)
    }

    init(tunnelID: UInt16, hopID: Signature, data: Data) {
        self.size = UInt16(6 + hopID.count + data.count)
        self.tunnelID = tunnelID
        self.hopID = hopID
        self.data = data
    }

    var dataRepresentation: Data {
        var array = [UInt8]()
        array.append(contentsOf: size.pack()!)
        array.append(contentsOf: type.rawValue.pack()!)
        array.append(contentsOf: tunnelID.pack()!)
        var data = Data(array)
        data.append(hopID.data)
        data.append(data)
        return data
    }
}
