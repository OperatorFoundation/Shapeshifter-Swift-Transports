//
//  File.swift
//  Replicant
//
//  Created by Adelita Schule on 11/30/18.
//

import Foundation
import ReplicantSwift

public struct ReplicantConfig
{
    public var serverPublicKey: SecKey
    public var chunkSize: Int
    public var chunkTimeout: Int
    public var addSequences: [SequenceModel]?
    public var removeSequences: [SequenceModel]?
    
    
    public init?(serverPublicKey: SecKey, chunkSize: Int, chunkTimeout: Int, addSequences: [SequenceModel]?, removeSequences: [SequenceModel]?)
    {
        guard chunkSize >= keySize + aesOverheadSize
            else
        {
            print("\nUnable to initialize ReplicantConfig: chunkSize (\(chunkSize)) cannot be smaller than keySize + aesOverheadSize (\(keySize + aesOverheadSize))\n")
            return nil
        }
        self.serverPublicKey = serverPublicKey
        self.chunkSize = chunkSize
        self.chunkTimeout = chunkTimeout
        self.addSequences = addSequences
        self.removeSequences = removeSequences
    }
}
