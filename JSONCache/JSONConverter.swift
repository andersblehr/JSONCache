//
//  JSONConverter.swift
//  JSONCache
//
//  Created by Anders Blehr on 09/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


public struct JSONConverter {
    
    public enum Conversion {
        case fromJSON
        case toJSON
    }
    
    
    public static func convert(_ conversion: Conversion, dictionary: [String: Any], qualifier: String? = nil) -> [String: Any] {
        
        var convertedDictionary = [String: Any]()
        for (key, value) in dictionary {
            convertedDictionary[convert(conversion, string: key, qualifier: qualifier)] = value
        }
        
        return convertedDictionary
    }
    
    
    public static func convert(_ conversion: Conversion, string: String, qualifier: String? = nil) -> String {
        
        switch conversion {
        case .fromJSON:
            if qualifier != nil && string == "description" {
                return camelCase(fromTitleCase: qualifier!) + "Description"
            }
            
            switch JSONCache.casing {
            case .camelCase:
                return string
            case .snake_case:
                if string.contains("_") {
                    return camelCase(fromTitleCase: string.components(separatedBy: "_").reduce("", { $0 + $1.capitalized }))
                } else {
                    return string
                }
            }
        case .toJSON:
            if string.hasSuffix("Description") {
                if qualifier == nil {
                    return "description"
                }
                
                if string == convert(.fromJSON, string: "description", qualifier: qualifier) {
                    return "description"
                }
            }
            
            switch JSONCache.casing {
            case .camelCase:
                return string
            case .snake_case:
                return string.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased()
            }
        }
    }
    
    
    // MARK: - Private implementation details
    
    private static func camelCase(fromTitleCase titleCase: String) -> String {
        
        var titleCase = titleCase
        
        return String(titleCase.remove(at: titleCase.startIndex)).lowercased() + titleCase
    }
}
