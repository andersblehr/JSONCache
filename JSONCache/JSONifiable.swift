//
//  JSONifiable.swift
//  JSONCache
//
//  Created by Anders Blehr on 12/03/2017.
//  Copyright © 2017 Anders Blehr. All rights reserved.
//

import Foundation


/// A type that can be represented as a JSON serializable dictionary
public protocol JSONifiable {
    
    /// Produce a JSON serializable dictionary that represents the type
    func toJSONDictionary() -> [String: Any]
}


public extension JSONifiable {
    
    /// If the type is a `struct`, produce a JSON serializable dictionary
    /// that represents the `struct`.
    public func toJSONDictionary() -> [String: Any] {
        
        var dictionary = [String: Any]()
        let isStruct = !(type(of:self) is AnyClass)
        
        if isStruct {
            for case let (label?, value) in Mirror(reflecting: self).children {
                let stringValue = "\(value)"
                
                if stringValue != "nil" && stringValue != ""  {
                    dictionary[label] = value
                }
            }
        }
        
        return JSONConverter.convert(.toJSON, dictionary: dictionary)
    }
}
