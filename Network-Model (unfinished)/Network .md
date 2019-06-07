# Network - Example

## Introduction 
This file describes our way to build an onion tunnel using an example path of message packages. 

## Components 
**Initiator**: receives the order to create an onion tunnel by the client. 

**Initiator-table**: 
This table starts empty with three columns Hostkey, Position and ID. Every node holds a hostkey and the initiator uses this hostkey to encrypt it´s messages between both nodes. The position simply counts the hop the node has in the network. The initiator retrieves the ID by the node. This helps the initiator to send packages which can refer to a eplicit node. This reduces the amount of nodes which needs to try to decrypt a packages.

**Hop 1 and 2**: These Hops are example hops that are used to disguise the network path.

**Hop-tables**: These tables save 3 columns, Source, Destination and a tunnel ID. This way the initiator don't need to send next hops, because every hop saves it's successor.

**Destination**: The Destination the initiator wants to communicate with.

## Packages
### Ping 
### Data (has it's own header)
### Response

## Network-Path

### Step 0 
The initiator gets a message to build an onion path to the destination.

### Step 1 
The initiator sends a ping message to Hop 1. The Hop 1 gets the Ping message. 

### Step 2 
Hop 1 creates a random ID and sends it back to the demandant through encrypted data in a response message.
The initiator receives this message and encryptes the data. It writes the received ID at one go with the position and hostkey in it's table

### Step 3 
Now the initiator knows how to explicit address the Hop 1. The initiator creates a ping message for the next hop, not knowing it's address. This packet will be encrypted using the hostkey of initiator and hop 1. This encrypted packet will be added to a not encrypted data packet (including a node ID, so every node knows if it should open this packet or just forward it) and send to the hop 1.

### Step 4 
The hop 1 knows that it should encrypt the data packet and evaluates it. The result is it should send a ping message to the next hop. For this Hop 1 looks up it's table, but won't find an entry. For this hop 1 asks the RPS server for the next hop. After receiving the next hop, the node saves all information in it's table and sends the ping message.

### Step 5
