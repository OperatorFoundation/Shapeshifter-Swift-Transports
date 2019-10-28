# Wisp

Wisp is a pluggable transport that is compatible with obfs4 servers.


## Using Wisp

### Swift Version:

Wisp is one of the transports available in the [Shapeshifter-Swift-Transports library](https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports). We recommend that you add this library to your Swift project using [Swift Package Manager](https://swift.org/package-manager/).
You can see example code for making a connection using Wisp in the [example.swift](https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports/blob/master/example.swift) file in the Shapeshifter-Swift-Transports project. Here is a summary of how you might make a connection with Optimizer:

1. Create an instance of WispConnectionFactory using the correct IP, port, and cert string for the obfs4 server:
    `let wispFactory = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)`
    
3. An optional connection is created by calling connect on your connection factory (this is designed to look and behave in the same way as Apple’s Network.framework):
    `maybeConnection?.stateUpdateHandler`
    
4. The rest of your networking code should be the same as if you were just using Network.framework. You can get state updates on your unwrapped connection via `connection.stateUpdate handler`, and start your connection by calling `maybeConnection?.start`.
