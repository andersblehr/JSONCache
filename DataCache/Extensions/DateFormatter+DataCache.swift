//
//  DateFormatter+DataCache.swift
//
//  Created by Anders Blehr on 11/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


internal extension DateFormatter {
    
    internal static func dateTime(from dateTimeString: String) -> Date {
        
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: Calendar.Identifier.iso8601)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        
        return dateFormatter.date(from: dateTimeString)!
    }
}
