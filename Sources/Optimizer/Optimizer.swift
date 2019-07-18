//
//  Optimizer.swift
//  Optimizer
//
//  Created by Mafalda on 7/12/19.
//

import Foundation
import Transport

// OptimizerConnectionFactory will use strategy's Choose function in Connect to choose which transport connection to return
// TODO: Move to Optimizer Target
public protocol Strategy {
    func choose(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
}

//enum Transport
//{
//    case protean
//    case wisp
//    case replicant
//
//    var connectionFactory: ConnectionFactory
//    {
//        switch self
//        {
//        case .protean:
//            return ProteanConnectionFactory
//        case .wisp:
//            return WispConnectionFactory
//        case .replicant:
//            return ReplicanctConnectionFactory
//        }
//    }
//}
//
//class Optimizer
//{
//    var currentTransport: Transport
//
//    init(availableTransports: [Transport])
//    {
//        self.currentTransport = strategy(availableTransports: availableTransports)
//    }
//
//    static func strategy(availableTransports: [Transport]) -> Transport
//    {
//        return availableTransports.first
//    }
//}
