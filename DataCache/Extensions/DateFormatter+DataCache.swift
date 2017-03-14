//
//  DateFormatter+DataCache.swift
//  DataCache
//
//  Created by Anders Blehr on 11/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


internal extension DateFormatter {
    
    internal static func date(fromISO8601String string: String) -> Date? {
        
        return iso8601DateFormatter.date(from: string)
    }
    
    
    internal static func iso8601String(from date: Date) -> String {
        
        return iso8601DateFormatter.string(from: date)
    }
    
    
    // Private implementation details
    
    private enum ISO8601Format: String {
        case withSeparators = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        case withoutSeparators = "yyyyMMdd'T'HHmmss'Z'"
    }
    
    private static var iso8601DateFormatter: DateFormatter {
        get {
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar(identifier: Calendar.Identifier.iso8601)
            dateFormatter.dateFormat = (JSONConverter.dateFormat == .iso8601WithSeparators ? ISO8601Format.withSeparators : ISO8601Format.withoutSeparators).rawValue
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            return dateFormatter
        }
    }
}
