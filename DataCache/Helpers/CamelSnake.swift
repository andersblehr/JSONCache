//
//  CamelSnake.swift
//  DataCache
//
//  Created by Anders Blehr on 09/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


internal struct CamelSnake {
    
    internal enum Casing {
        case camelCase
        case snake_case
    }
    
    
    internal static func convert(dictionary: [String: Any], toCase targetCasing: Casing, qualifier: String? = nil) -> [String: Any] {
        
        var convertedDictionary = [String: Any]()
        
        for (key, value) in dictionary {
            convertedDictionary[convert(string: key, toCase: targetCasing, qualifier: qualifier)] = value
        }
        
        return convertedDictionary
    }
    
    
    internal static func convert(string: String, toCase targetCasing: Casing, qualifier: String? = nil) -> String {
        
        switch targetCasing {
        case .camelCase:
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
        case .snake_case:
            let convertedString = string.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased()
            
            return convertedString.hasSuffix("_description") ? "description" : convertedString
        }
    }
}
