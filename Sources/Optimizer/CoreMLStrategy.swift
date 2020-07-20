//
//  CoreMLStrategy.swift
//  Optimizer
//
//  Created by Mafalda on 8/14/19.
//

import Foundation
import Logging
import Transport
import CoreML
import CreateML

class CoreMLStrategy: Strategy
{
    let log: Logger
    var transports: [ConnectionFactory]
    var index = 0
    var indices = [Int]()
    var durations = [Int]()
    var trackDictionary = [String: Bool]()
    
    var classifier: MLClassifier?
    
    init(transports: [ConnectionFactory], logger: Logger)
    {
        self.transports = transports
        self.log = logger
    }
    
    func choose() -> ConnectionFactory?
    {
        var transport = transports[index]
        var alreadyTried = checkIfTried()
        let startIndex = index
        incrementIndex()
        
        // Make sure that every transport in the list has been tried at least once
        while startIndex != index
        {
            if alreadyTried == false
            {
                return transport
            }
            else
            {
                incrementIndex()
                transport = transports[index]
                alreadyTried = checkIfTried()
                continue
            }
        }
        
        // If we have tried all of the transports
        // Use the model to make a prediction
        if classifier != nil
        {
            var dataTable = MLDataTable()
            let durationColumnName = "millisecondsToConnect"
            let durationColumn = MLDataColumn([1])
            
            dataTable.addColumn(durationColumn, named: durationColumnName)
            
            do
            {
                let predictions = try classifier!.predictions(from: dataTable)
                if let firstIndexPrediction = predictions.ints?.element(at: 0)
                {
                    log.debug("\nChose a CoreML predicted transport: \(transports[firstIndexPrediction].name)")
                    return transports[firstIndexPrediction]
                }
            }
            catch
            {
                log.error("\nError using classifier: \(error)")
                return nil
            }
        }
        
        log.debug("\nFailed to predict a transport, choosing transport at index \(index).")
        return transports[index]
    }
    
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int)
    {
        log.debug("\n📋  CoreMLStrategy received a report.  📋\nTransport: \(transport.name)\nSuccessfulConnection?: \(successfulConnection)\nMillisecondsToConnect: \(millisecondsToConnect)")
        
        trackDictionary[transport.name] = true
        
        if successfulConnection
        {
            // Get the index in our array for this transport
            if let thisIndex = getIndex(ofTransport: transport, inTransports: transports)
            {
                // Add Index to our list
                indices.append(thisIndex)
                
                // Add milliseconds to our list in parallel
                durations.append(millisecondsToConnect)
            }
        }
        
        if !indices.isEmpty && !durations.isEmpty
        {
            //Create a model
            var dataTable = MLDataTable()
            let indexColumnName = "index"
            let durationColumnName = "millisecondsToConnect"
            let indexColumn = MLDataColumn(indices)
            let durationColumn = MLDataColumn(durations)
            
            dataTable.addColumn(indexColumn, named: indexColumnName)
            dataTable.addColumn(durationColumn, named: durationColumnName)
            
            let (_, trainingTable) = dataTable.randomSplit(by: 0.20)
            
            do
            {
                let classifier = try MLClassifier(trainingData: trainingTable, targetColumn: indexColumnName)
                self.classifier = classifier
            }
            catch
            {
                log.error("\nError creating a classifier: \(error)")
            }
        }
    }
    
    func incrementIndex()
    {
        index += 1
        
        if index >= transports.count
        {
            index = 0
        }
    }
    
    func checkIfTried() -> Bool
    {
        let transport = transports[index]
        if let triedTransport = trackDictionary[transport.name]
        {
            return triedTransport
        }
        else
        {
            return false
        }
    }
    
    
}
