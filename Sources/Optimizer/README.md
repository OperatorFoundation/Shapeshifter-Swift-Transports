# Optimizer


Optimizer is a pluggable transport that uses one of several possible “Strategies” to choose between the transports you provide to create a connection. It is not a standalone transport, but is rather a mechanism for choosing between various transports in order to find the one best suited for the user’s needs. For more information about pluggable transports, please refer to [pluggabletransports.info](https://www.pluggabletransports.info/).

Here is a list of the currently available Optimizer strategies:

**Rotate Strategy**: This strategy simply rotates through the list of provided transports and tries the next one in the list each time a connection is needed.

**Choose Random Strategy**: A transport is selected at random from the list for each connection request.

**Track Strategy**: A strategy that  attempts to connect with each of the provided transports. It keeps track of which transports are connecting successfully and favors using those.

**Minimize Dial Strategy**: The transport is chosen based on which has been shown to connect the fastest.

**CoreMLStrategy** (Swift version only): Uses machine learning to select the best transport based on successful connections and dial time.


## Using Optimizer

### Swift Version:

Optimizer is one of the transports available in the [Shapeshifter-Swift-Transports library](https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports). We recommend that you add this library to your Swift project using [Swift Package Manager](https://swift.org/package-manager/).
You can see example code for making a connection using Optimizer in the [example.swift](https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports/blob/master/example.swift) file in the Shapeshifter-Swift-Transports project. Here is a summary of how you might make a connection with Optimizer:

1. First you will need to initialize the transports you would like Optimizer to use:
    `let wispTransport = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)`
    `let proteanTransport = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)`
    
2. Create an array with these transports:
    `let possibleTransports:[ConnectionFactory] = [wispTransport, proteanTransport]`
    
3. Initialize the strategy of your choice using the array of transports you created:
    `let strategy = ChooseRandom(transports: possibleTransports)`
    
4. Create an instance of OptimizerConnectionFactory using your new Strategy instance:
    `let connectionFactory = OptimizerConnectionFactory(strategy: strategy)`
    
5. An optional connection is created by calling connect on your connection factory (this is designed to look and behave in the same way as Apple’s Network.framework):
    `let possibleConnection = connectionFactory!.connect(using: .tcp)`
    
6. The rest of your networking code should be the same as if you were just using Network.framework. You can get state updates on your unwrapped connection via connection.stateUpdate handler, and you start your connection by calling connection.start.
