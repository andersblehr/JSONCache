//
//  JSONConverter.swift
//  JSONCache
//
//  Created by Anders Blehr on 09/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


/// A simple casing converter for dictionary keys, converting either from `snake_case`
/// to `camelCase`, or from `camelCase` to `snake_case`.

public struct JSONConverter {
    
    /// Enum definining the supported JSON conversions
    public enum Conversion {
        /// Convert from JSON. If `JSONCache.casing` is `.snake_case`, the conversion
        /// is from `snake_case` to `camelCase`; if `JSONCache.casing` is `.camelCase`,
        /// no casing conversion is done, but reserved words are mapped to qualified
        /// counterparts (see `convert(_:dictionary:qualifier:)` for details).
        case fromJSON
        /// Convert to JSON. If `JSONCache.casing` is `.snake_case`, the conversion is
        /// from `camelCase` to `snake_case`; if `JSONCache.casing` is `.camelCase`, no
        /// casing conversion is done, but qualified attribute names are mapped to
        /// their unqualified counterparts (see the `convert(_:dictionary:qualifier:)`
        /// for details).
        case toJSON
    }
    
    
    /// Perform the specified casing `conversion` on the keys in `dictionary`, as
    /// governed by the `JSONCache.casing` setting
    ///
    /// - Parameters:
    ///   - conversion: Enum specifying if the conversion is from JSON or to JSON.
    ///   - dictionary: The dictionary whose keys are to be converted.
    ///   - qualifier: A string qualifier to prefix onto any reserved words among JSON
    ///     keys when converting from JSON, or to strip away from reserved words when
    ///     converting to JSON. Defaults to `nil` if not given. If for instance the 
    ///     qualifier is `EntityName`, the JSON key `description` will be converted
    ///     to `entityNameDescription`. Conversely, the dictionary key
    ///     `entityNameDescription` will be converted to the JSON key `description`.
    ///     The key `someOtherDescription`, however, will be converted to
    ///     `some_other_description` (or not converted at all if `JSONCache.casing` is
    ///     `.camelCase`). If `qualifier` is not given, any string that ends with 
    ///     `-Description` will be converted to `description` when converting to JSON.
    ///     Qualification and dequalification of reserved words is done regardless of
    ///     whether `JSONCache.casing` specifies `snake_case` or `camelCase`.
    
    public static func convert(_ conversion: Conversion, dictionary: [String: Any], qualifier: String? = nil) -> [String: Any] {
        
        var convertedDictionary = [String: Any]()
        for (key, value) in dictionary {
            convertedDictionary[convert(conversion, string: key, qualifier: qualifier)] = value
        }
        
        return convertedDictionary
    }
    
    
    /// Perform the specified casing `conversion` on `string`, as governed by the
    /// `JSONCache.casing` setting
    /// 
    /// - Parameters:
    ///   - conversion: Enum specifying if the conversion is from JSON or to JSON.
    ///   - string: The string to be converted.
    ///   - qualifier: A string qualifier to prefix onto the string when converting
    ///     from JSON and the string represents a reserved word, or to strip away from
    ///     the string when converting to JSON. Defaults to `nil` if not given. If for
    ///     instance the qualifier is `EntityName`, the reserved word `description`
    ///     will be converted to `entityNameDescription` when converting from JSON.
    ///     Conversely, the string `entityNameDescription` will be converted to
    ///     `description` when converting to JSON. The string `someOtherDescription`,
    ///     however, will be converted to `some_other_description` (or not converted at
    ///     all if `JSONCache.casing` is `.camelCase`). If `qualifier` is not given,
    ///     any string that ends with `-Description` will be converted to `description`
    ///     when converting to JSON. Qualification and dequalification of reserved
    ///     words is done regardless of whether `JSONCache.casing` specifies
    ///     `snake_case` or `camelCase`.
    
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
