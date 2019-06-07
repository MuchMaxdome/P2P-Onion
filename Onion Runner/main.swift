//
//  main.swift
//  Onion Runner
//
//  Created by Finn Gaida on 23.05.19.
//

import Foundation
import CommandLineKit

func parseArgs() -> Config? {
    let flags = Flags()

    let port = flags.int("p", "port", description: "This is port for Onion’s P2P protocol i.e., the port number on which Onion accepts tunnel connections from Onion modules of other peers. This is diﬀerent from the port where it listens for API connections. This value is used by the RPS module to advertise the socket the onion module is listening on, so that other peers’ onion modules could connect to it.", value: 1337)
    let apiPort = flags.int("a", "api-port", description: "Second socket that's open for connections from other onion modules to connect to this instance as an intermediate hop", value: 1338)
    let hostname = flags.string("n", "hostname", description: "Similar to `P2P PORT` this determines the interface on which Onion listens for incoming P2P connections.", value: "127.0.0.1")
    let hostkey = flags.string("k", "hostkey", description: "Path to a hostkey file representing this specific hop", value: "hostkey.pem")
    let numberOfHops = flags.int("H", "minimum-hops", description: "Minimum number of hops to connect to before reaching the final destination", value: 2)
    let verbose = flags.option("v", "verbose", description: "Set this flag to receive debugging output")
    _ = flags.option("h", "help", description: "Prints this help message")

    // Parse the command-line arguments and return error message if parsing fails
    if let failure = flags.parsingFailure() {
        print(failure)
        return nil
    } else if
        let port = port.value,
        let apiPort = apiPort.value,
        let hostname = hostname.value,
        let hostkeyPath = hostkey.value,
        let hostkey = Hostkey(path: hostkeyPath),
        let numberOfHops = numberOfHops.value
    {
        guard port != apiPort else { print("Module and API port must be different."); return nil }
        return Config(modulePort: port, apiPort: apiPort, hostname: hostname, hostkey: hostkey, numberOfHops: numberOfHops, verbose: verbose.wasSet)
    } else {
        print("Couldn't unwrap arguments - please use the right format")
        return nil
    }
}

func main() {
    guard let config = parseArgs() else { return }
    Onion.shared.startServer(config: config)
}

main()
