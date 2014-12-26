//
//  StringExtensions.swift
//  SwiFTP
//
//  Created by Guilherme Rambo on 25/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

import Foundation

public extension String {
    
    public static func stringForFileSize(size:Double) -> String {
        if (size <= 0) {
            return "-"
        }
        
        if (size == 1) {
            return "1 byte"
        } else if (size < 1024) {
            return "\(size) bytes"
        } else if (size < (1024 * 1024 * 0.1)) {
            return String(format: "%.1fKB", size / 1024)
        } else if (size < (1024.0 * 1024.0 * 1024.0 * 0.1)) {
            return String(format: "%.1fMB", size / (1024 * 1024))
        } else {
            return String(format: "%.1fGB", size / (1024 * 1024 * 1024))
        }
    }
    
    public func convertFromRomanToUTF8() -> String
    {
        var data = self.dataUsingEncoding(NSMacOSRomanStringEncoding, allowLossyConversion: false)
        if (data == nil) {
            return self
        }
        
        var newString = NSString(data: data!, encoding: NSUTF8StringEncoding)
        if (newString == nil) {
            return self
        }
        
        return newString!
    }
    
}