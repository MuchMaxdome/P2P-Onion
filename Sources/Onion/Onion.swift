import SwiftSocket
import SwiftTLS

/// Singleton struct supposed to handle the delegation of tasks, mainly reacting to incoming messages (from the UI module)
class Onion {

    /// Singleton
    static let shared = Onion()

    /// Store the config passed via launch arguments
    fileprivate var config: Config!

    /// Stores all active tunnels by their ID
    fileprivate var tunnels: [UInt16: Tunnel] = [:]

    /// Spin up a TLS TCP socket on the specified hostname:port in config
    public func startServer(config: Config) {
        self.config = config

        let uiServer = TCPServer(address: config.hostname, port: Int32(config.modulePort))
        switch uiServer.listen() {
        case .success: print("UI Server listenning on \(config.hostname):\(config.modulePort)")
        case .failure(let error):
            return print("UI Server couldn't listen on Port \(config.modulePort) - probably already in use: \(error)")
        }

        // spin up the internal API server as well (listenning for intermediate hop calls from another Onion module)
        DispatchQueue.global().async {
            self.startAPIServer(config: config)
        }

        while true {
            guard let client = uiServer.accept() else { return print("Client connection failed") }
            guard let input = client.read(100, timeout: tcpTimeout) else { return print("Timeout") }
            guard let packet = PacketParser.from(Data(input)) else { return print("Unknown packet format") }

            handle(packet, from: client)
        }
    }

    /// Second open server socket (besides the one listenning for commands from the UI module) - handling incoming requests to be an intermediate hop
    private func startAPIServer(config: Config) {
        let apiServer = TCPServer(address: config.hostname, port: Int32(config.apiPort))
        switch apiServer.listen() {
        case .success: print("API Server listenning on \(config.hostname):\(config.modulePort)")
        case .failure(let error):
            return print("API server couldn't listen on Port \(config.modulePort) - probably already in use: \(error)")
        }

        while true {
            guard
                let client = apiServer.accept(),
                let input = client.read(100, timeout: tcpTimeout),
                let packet = PacketParser.from(Data(input))
            else { continue }

            handle(packet, from: client)
        }
    }

    /// Delegate the packet to the corresponding action
    private func handle(_ packet: Packet, from client: TCPClient?) {
        switch packet {

            // Onion packets
        case let p as TunnelBuild:
            buildTunnel(destination: PeerHop(address: p.destAddr, port: p.destPort, isIntermediate: false, hostkey: p.destHostkey, socket: nil))

        case let p as TunnelDestroy:
            teardownTunnel(with: p.tunnelID)

        case let p as TunnelData:
            handleData(p)

        case let p as TunnelError:
            handleError(p)

        case let p as TunnelCover:
            handleCover(p)

            // API packets
        case let p as APIPing:
            guard let client = client else { fatalError("Can't handle Ping requests without a client") }
            handlePing(p, from: client)

        case let p as APINextHopQuery:
            let nextHop = handleNextHopQuery(p)

        case let p as APIFinalHopQuery:
            let finalHop = handleFinalHopQuery(p)

        case let p as APIData:
            _ = handleData(p, from: client)

        default:
            print("Can't handle packet of type \(type(of: packet)) this way")
        }
    }

    // MARK: - module calls

    /* Contains the complete procedure for building the tunnel
     * 1. get a first hop from the RPS
     * 2. connect, secure connection (TLS)
     * 3. repeat 1. + 2. until we are connected to >= `numberOfHops` peers
     * 4. add final hop + secure complete tunnel
     * 5. send tunnel ready message to all peers
     */
    private func buildTunnel(destination: PeerHop) {
        print("Attempting to build tunnel to \(destination)")

        // make up tunnel ID
        var tunnel = Tunnel()
        tunnel.state = .building
        tunnels[tunnel.id] = tunnel

        // commence tunnel build by simulating an incoming next hop query
        let fakeNextHopQuery = APINextHopQuery(tunnelID: tunnel.id)
        guard var nextHop = handleNextHopQuery(fakeNextHopQuery) else {
            return print("Connecting initial hop failed")
        }
        tunnel.nextHop = nextHop

        // now we can start to send packages to the next hop
        var hops: [Hop] = [nextHop]
        while hops.count < config.numberOfHops {
            let request = APINextHopQuery(tunnelID: tunnel.id)
            guard let key = nextHop.hostkey else { break }
            let encrypted = Crypto.encrypt(request.dataRepresentation, key: key)
            let data = APIData(tunnelID: tunnel.id, hopID: key.signature, data: encrypted)

            guard
                let socket = nextHop.socket,
                case .success = socket.send(data: data.dataRepresentation)
            else {
                print("Couldn't send next hop request")
                break
            }

            guard
                let responseData = socket.read(1024, timeout: tcpTimeout),
                let responsePacket = PacketParser.from(Data(responseData)) as? APIData,
                let response = handleData(responsePacket, from: socket) as? APINextHopResponse
            else {
                print("Next hop query timed out.")
                break
            }

            hops.append(AnonymousHop(hostkey: response.nextHopHostkey, socket: nil))
        }

        // now add the final hop to the onion
        guard
            let finalHopKey = destination.hostkey,
            let lastHopKey = hops.last?.hostkey
        else { return print("Invalid final hop") }

        let finalQuery = APIFinalHopQuery(tunnelID: tunnel.id, destPort: destination.port, destAddr: destination.address, destHostkey: finalHopKey)
        let encryptedFinalQuery = Crypto.encrypt(finalQuery.dataRepresentation, key: lastHopKey)
        let dataPacket = APIData(tunnelID: tunnel.id, hopID: lastHopKey.signature, data: encryptedFinalQuery)

        guard
            let nextHopSocket = nextHop.socket,
            case .success = nextHopSocket.send(data: dataPacket.dataRepresentation)
        else {
            return print("Couldn't send final hop query")
        }

        guard
            let responseData = nextHopSocket.read(1024, timeout: tcpTimeout),
            let responsePacket = PacketParser.from(Data(responseData)) as? APIData,
            let response = handleData(responsePacket, from: nextHopSocket) as? APINextHopResponse
        else {
                return print("Final hop query timed out.")
        }

        // at this point we are finally done.
        // we can check for trivial errors by comparing the hostkey of the final hop versus our desired destination
        assert(response.nextHopHostkey == destination.hostkey!)
    }

    private func teardownTunnel(with id: UInt32) {
        // TODO:
    }

    private func handleData(_ packet: TunnelData) {
        // TODO:
    }

    private func handleError(_ packet: TunnelError) {

    }

    private func handleCover(_ packet: TunnelCover) {

    }

    // MARK: - API calls

    /// Respond with own hostkey and Onion version
    private func handlePing(_ packet: APIPing, from client: TCPClient) {

        // save senders' hostkey so we can encrypt later communication
        var tunnel = Tunnel(id: packet.tunnelID)
        guard let address = Address(client.address) else { return print("Invalid address: \(client.address)") }
        let previous = PeerHop(address: address, port: UInt16(client.port), isIntermediate: true, hostkey: packet.hostkey, socket: client)
        tunnel.previousHop = previous
        tunnels[packet.tunnelID] = tunnel

        let response = APIPingResponse(tunnelID: packet.tunnelID, hostkey: config.hostkey)
        let encryptedData = Crypto.encrypt(response.dataRepresentation, key: packet.hostkey)
        let data = APIData(tunnelID: packet.tunnelID, hopID: packet.hostkey.signature, data: encryptedData)

        switch client.send(data: data.dataRepresentation) {
        case .success: break
        case .failure(let error): print("Couldn't send ping reply: \(error)")
        }
    }

    private func handleNextHopQuery(_ packet: APINextHopQuery) -> Hop? {
        // 1. get random hop from RPS module
        guard var hop = RPS.getRandomHop() else {
            return nil
        }

        // 2. connect and secure connection
        let connection = TCPClient(address: hop.address.description, port: Int32(hop.port))
        guard case .success = connection.connect(timeout: tcpTimeout) else {
            print("Couldn't connect to hop")
            return nil
        }

        hop.socket = connection

        // 3. ping hop
        let ping = APIPing(tunnelID: packet.tunnelID, hostkey: config.hostkey)
        guard case .success = connection.send(data: ping.dataRepresentation) else {
            print("Couldn't send API PING request to hop")
            return nil
        }

        // 4. parse ping response
        guard
            let pingResponseData = connection.read(1024, timeout: tcpTimeout),
            let pingResponsePacket = PacketParser.from(Data(pingResponseData)) as? APIData,
            let pingResponse = handleData(pingResponsePacket, from: nil) as? APIPingResponse
        else {
                print("API Ping response for hop timed out")
                return nil
        }

        // 5. craft next hop response
        let nextHopResponse = APINextHopResponse(tunnelID: packet.tunnelID, nextHopHostkey: pingResponse.hostkey)
        guard
            let previousHop = tunnels[packet.tunnelID]?.previousHop,
            let hostkey = previousHop.hostkey
        else {
            print("Can't handle ping response for unknown host")
            return hop // if this is the initial next hop query, the previous hop will be nil
        }
        let encryptedData = Crypto.encrypt(nextHopResponse.dataRepresentation, key: hostkey)
        let data = APIData(tunnelID: packet.tunnelID, hopID: hostkey.signature, data: encryptedData)

        // 6. send next hop response
        guard
            let socket = previousHop.socket,
            case .success = socket.send(data: data.dataRepresentation)
        else {
            print("Couldn't send API Next hop response to hop")
            return nil
        }

        return hop
    }

    private func handleFinalHopQuery(_ packet: APIFinalHopQuery) -> Hop? {

        // 1. get random hop from RPS module
        var hop = PeerHop(address: packet.destAddr, port: packet.destPort, isIntermediate: false, hostkey: nil, socket: nil)

        // 2. connect and secure connection
        let connection = TCPClient(address: hop.address.description, port: Int32(hop.port))
        guard case .success = connection.connect(timeout: tcpTimeout) else {
            print("Couldn't connect to hop")
            return nil
        }

        hop.socket = connection

        // 3. ping hop
        let ping = APIPing(tunnelID: packet.tunnelID, hostkey: config.hostkey)
        guard case .success = connection.send(data: ping.dataRepresentation) else {
            print("Couldn't send API PING request to hop")
            return nil
        }

        // 4. parse ping response
        guard
            let pingResponseData = connection.read(1024, timeout: tcpTimeout),
            let pingResponsePacket = PacketParser.from(Data(pingResponseData)) as? APIData,
            let pingResponse = handleData(pingResponsePacket, from: nil) as? APIPingResponse
            else {
                print("API Ping response for hop timed out")
                return nil
        }

        hop.hostkey = pingResponse.hostkey

        // 5. craft next hop response
        let nextHopResponse = APINextHopResponse(tunnelID: packet.tunnelID, nextHopHostkey: pingResponse.hostkey)
        guard
            let previousHop = tunnels[packet.tunnelID]?.previousHop,
            let hostkey = previousHop.hostkey
            else {
                print("Can't handle ping response for unknown host")
                return hop // if this is the initial next hop query, the previous hop will be nil
        }
        let encryptedData = Crypto.encrypt(nextHopResponse.dataRepresentation, key: hostkey)
        let data = APIData(tunnelID: packet.tunnelID, hopID: hostkey.signature, data: encryptedData)

        // 6. send next hop response
        guard
            let socket = previousHop.socket,
            case .success = socket.send(data: data.dataRepresentation)
            else {
                print("Couldn't send API Next hop response to hop")
                return nil
        }

        return hop
    }

    private func handleData(_ packet: APIData, from client: TCPClient?) -> APIPacket? {
        // first check if this is adressed to us
        if packet.hopID == config.hostkey.signature {

            // decrypt the inner packet and handle that again
            let decrypted = Crypto.decrypt(packet.data, key: config.hostkey)
            guard let innerPacket = PacketParser.from(decrypted) as? APIPacket else {
                print("Can't handle incoming data API packet. Break here for more info")
                return nil
            }
            return innerPacket
        }

        // packet is not meant for us, passthrough to tunnel route
        guard let nextHop = tunnels[packet.tunnelID]?.nextHop, let socket = nextHop.socket else {
            print("No next hop available, can't forward packet!")
            return nil
        }

        switch socket.send(data: packet.dataRepresentation) {
        case .success: break
        case .failure(let error): print("Couldn't forward packet through tunnel: \(error)")
        }

        return nil
    }
}
