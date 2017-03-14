//
//  JSONConverter.swift
//  DataCache
//
//  Created by Anders Blehr on 09/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


internal struct JSONConverter {
    
    internal enum Direction {
        case fromJSON
        case toJSON
    }
    
    internal enum Casing {
        case camelCase
        case snake_case
    }
    
    internal enum DateFormat {
        case iso8601WithSeparators
        case iso8601WithoutSeparators
        case timeIntervalSince1970
    }
    
    internal static var casing: Casing = .camelCase
    internal static var dateFormat: DateFormat = .iso8601WithSeparators
    
    
    internal static func convert(_ direction: Direction, dictionary: [String: Any], qualifier: String? = nil) -> [String: Any] {
        
        if casing == .camelCase {
            return dictionary
        }
        
        var convertedDictionary = [String: Any]()
        for (key, value) in dictionary {
            convertedDictionary[convert(direction, string: key, qualifier: qualifier)] = value
        }
        
        return convertedDictionary
    }
    
    
    internal static func convert(_ direction: Direction, string: String, qualifier: String? = nil) -> String {
        
        if casing == .camelCase {
            return string
        }
        
        switch direction {
        case .fromJSON:
            if string.contains("_") {
                var convertedString = ""
                let components = string.components(separatedBy: "_")
                for (i, component) in components.enumerated() {
                    convertedString += i == 0 ? component : component.capitalized
                }
                
                return convertedString
            } else if string == "description" && qualifier != nil {
                return qualifier!.lowercased() + "Description"
            } else {
                return string
            }
        case .toJSON:
            let convertedString = string.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased()
            
            return convertedString.hasSuffix("_description") ? "description" : convertedString
        }
    }
}
