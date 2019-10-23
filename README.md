# Shapeshifter-Swift-Transports
Shapeshifter Swift Transports is a set of Pluggable Transports, written in Swift, implementing the upcoming (currently unpublished) Swift API from the Pluggable Transports [2.1 specification](https://github.com/Pluggable-Transports/Pluggable-Transports-spec)

### Shapeshifter Transports

This is the repository for the shapeshifter transports library for the Swift
programming language. If you are looking for a tool which you can install and
use from the command line, take a look at the [dispatcher](https://github.com/OperatorFoundation/shapeshifter-transports) instead.

The transports implement the Pluggable Transports 2.1 draft 1 specification available [here](https://github.com/Pluggable-Transports/Pluggable-Transports-spec/blob/master/releases/PTSpecV2.1Draft1/Pluggable%20Transport%20Specification%20v2.1%20-%20Swift%20Transport%20API%20v1.0%2C%20Draft%201.pdf) Specifically,
they implement the Swift Transports API v2.1 draft 1.

The purpose of the transport library is to provide a set of different
transports. Each transport implements a different method of shapeshifting
network traffic. The goal is for application traffic to be sent over the network
in a shapeshifted form that bypasses network filtering, allowing
the application to work on networks where it would otherwise be blocked or
heavily throttled.

The following transports are currently provided by this library:

#### Wisp

Wisp is a native Swift transport that is compatible with obfs4 servers.

#### Optmizer

Optimizer is a pluggable transport that uses one of several possible “Strategies” to choose between the transports you provide to create a connection. It is not a standalone transport, but is rather a mechanism for choosing between various transports in order to find the one best suited for the user’s needs.

See the [README](https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports/tree/master/Sources/Optimizer) for information on usage.

#### Protean

#### Meek

Swift implementation of the Meek transport

## Installation

This library can be installed using  [Swift Package Manager](https://swift.org/package-manager/). Please see instructions for using an individual transport in that transport's readme. 
