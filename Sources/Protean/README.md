# Protean


Protean is a pluggable transport that allows you to configure your own obfuscation.


## Using Protean

### Swift Version:

Protean is one of the transports available in the [Shapeshifter-Swift-Transports library](https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports). We recommend that you add this library to your Swift project using [Swift Package Manager](https://swift.org/package-manager/).
You can see example code for making a connection using Protean in the [example.swift](https://github.com/OperatorFoundation/Shapeshifter-Swift-Transports/blob/master/example.swift) file in the Shapeshifter-Swift-Transports project. Here is a summary of how you might make a connection with Optimizer:

1. First you will need to create the header, encryption, and sequences you want to use. Use these to create a protean config object:

` let sequenceModel = ByteSequenceShaper.SequenceModel(index: 0, offset: 0, sequence:  sequence, length: 256)
 let sequenceConfig = ByteSequenceShaper.Config(addSequences: [sequenceModel], removeSequences: [sequenceModel])`

`let bytes = Data(count: 32)
 let encryptionConfig = EncryptionShaper.Config(key: bytes)`

`let header = Data([139, 210, 37])
 let headerConfig = HeaderShaper.Config(addHeader: header, removHeader: header)`
 
 `let proteanConfig = Protean.Config(byteSequenceConfig: sequenceConfig, encryptionConfig: encryptionConfig, headerConfig: headerConfig)`

2. Create an instance of ProteanConnectionFactory using your new Config instance:
    `let proteanConnectionFactory = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)`
    
3. An optional connection is created by calling connect on your connection factory (this is designed to look and behave in the same way as Apple’s Network.framework):
    `let possibleConnection = proteanConnectionFactory.connect(using: .tcp)`
    
4. The rest of your networking code should be the same as if you were just using Network.framework. You can get state updates on your unwrapped connection via connection.stateUpdate handler, and you start your connection by calling connection.start.
