//
//  Date+JSONCache.swift
//  JSONCache
//
//  Created by Anders Blehr on 14/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


public extension Date {
    
    /// Create a `Date` instance from a JSON value.
    /// - Parameters:
    ///   - value: The JSON value from which to create a `Date` instance. The
    ///     `JSONCache.dateFormat` setting governs how to the value is parsed.
    
    public init(fromJSONValue value: Any) {
        
        switch JSONCache.dateFormat {
        case .iso8601WithSeparators, .iso8601WithoutSeparators:
            if let date = DateFormatter.date(fromISO8601String: value as! String) {
                self.init(timeIntervalSince1970: date.timeIntervalSince1970)
            } else {
                self.init(timeIntervalSince1970: 0)
            }
        case .timeIntervalSince1970:
            if let timeInterval = value as? Double {
                self.init(timeIntervalSince1970: timeInterval)
            } else {
                self.init(timeIntervalSince1970: 0)
            }
        }
    }
    
    
    /// Produce a JSON serializable value from this `Date` instance. The
    /// `JSONCache.dateFormat` setting governs the type and format of the produced
    /// value.
    /// - Returns: A JSON serializable value representing this `Date` instance.
    
    public func toJSONValue() -> Any {
        
        switch JSONCache.dateFormat {
        case .iso8601WithSeparators, .iso8601WithoutSeparators:
            return DateFormatter.iso8601String(from: self)
        case .timeIntervalSince1970:
            return self.timeIntervalSince1970
        }
    }
}
