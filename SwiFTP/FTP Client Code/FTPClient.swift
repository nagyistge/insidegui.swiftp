//
//  FTPClient.swift
//  SwiFTP
//
//  Created by Guilherme Rambo on 24/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

import Foundation

public class FTPClient: NSObject, NSStreamDelegate {
    public var url:NSURL?
    public var status:String?
    public var failed = false
    public var done = false
    
    var networkStream:NSInputStream!
    var listData:NSMutableData?
    public var listEntries:NSMutableArray?
    
    var updateStatusCallback: ((client: FTPClient) -> ())?
    
    init(url: NSURL?) {
        self.url = url
    }
    
    func list(updateStatus: (client: FTPClient) -> ()) {
        updateStatusCallback = updateStatus
        
        if (url == nil) {
            failed = true
            status = "Failed: invalid URL"
            updateStatusCallback!(client: self)
            return
        }

        listData = NSMutableData()
        let tempStream:Unmanaged<CFReadStream>? = CFReadStreamCreateWithFTPURL(nil, url)
        networkStream = tempStream!.takeRetainedValue()
        if (networkStream == nil) {
            failed = true
            status = "Failed: couldn't open stream"
            updateStatusCallback!(client: self)
            return
        }
        
        networkStream.delegate = self
        networkStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        networkStream.open()
    }
    
    // MARK: Stream events
    
    func streamOpenCompleted()
    {
        failed = false
        status = "Connection opened"
    }
    
    func streamHasBytesAvailable()
    {
        failed = false
        var bytesRead = 0
        var bufferSize = 32768
        var buffer:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.alloc(bufferSize)

        bytesRead = networkStream.read(buffer, maxLength: bufferSize)
        if (bytesRead < 0) {
            streamErrorOccurred()
        } else if (bytesRead == 0) {
            streamFinished()
        } else {
            listData?.appendBytes(buffer, length: bytesRead)
            
            parseStreamData()
        }
    }
    
    func streamErrorOccurred(customStatus: String? = nil)
    {
        done = true
        failed = true
        if (customStatus == nil) {
            status = "Connection failed for some unknown reason"
        } else {
            status = customStatus
        }

        updateStatusCallback!(client: self)
    }
    
    func streamFinished()
    {
        done = true
        failed = false
        status = "Done"
        updateStatusCallback!(client: self)
        
        networkStream.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        networkStream.delegate = nil
        networkStream.close()
        networkStream = nil
    }
    
    // MARK: NSStreamDelegate Protocol
    
    public func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch (eventCode) {
            case NSStreamEvent.OpenCompleted:
                streamOpenCompleted()
            case NSStreamEvent.HasBytesAvailable:
                streamHasBytesAvailable()
            case NSStreamEvent.ErrorOccurred:
                streamErrorOccurred()
            default:
                println("Stream event not handled. Don't worry.")
        }
    }
    
    // MARK: Parsing stream data
    
    func parseStreamData() {
        var newEntries = NSMutableArray()
        var offset = 0
        var bytesConsumed:CFIndex
        
        do {
            var bufferLength = (self.listData!.length-offset)
            var thisEntry = UnsafeMutablePointer<Unmanaged<CFDictionary>?>.alloc(bufferLength)
            
            var buffer = UnsafePointer<UInt8>(self.listData!.bytes).advancedBy(offset)
            bytesConsumed = CFFTPCreateParsedResourceListing(nil, buffer, bufferLength, thisEntry)

            if (bytesConsumed > 0) {
                var dictRef = thisEntry.memory!
                let dict:NSDictionary = dictRef.takeRetainedValue()
                
                newEntries.addObject(dict)
                
                offset += bytesConsumed
            }
        
            if (bytesConsumed < 0) {
                streamErrorOccurred(customStatus: "Failed to parse")
                break;
            }
        } while (bytesConsumed > 0);
        
        if (newEntries.count != 0) {
            self.append(newEntries)
        }
    }
    
    func append(newEntries: NSMutableArray) {
        if (listEntries == nil) {
            listEntries = NSMutableArray()
        }
        
        listEntries!.addObjectsFromArray(newEntries)
    }
}